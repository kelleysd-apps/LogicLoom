"""
Context Retriever - Semantic Search for Codebase Context
DS-STAR Multi-Agent Enhancement - Feature 001

Purpose:
    Provides semantic search over specifications, plans, and decisions.
    Uses sentence-transformers for embedding-based similarity matching.
    Implements graceful degradation to TF-IDF keyword search if embeddings slow.

Constitutional Compliance:
    - Principle I: Library-First - Retriever is standalone library
    - Principle V: Progressive Enhancement - Starts simple (TF-IDF), adds complexity (embeddings) only if needed
    - FR-031: Context retrieval must return in <2 seconds

Configuration:
    Loads settings from .logic-loom/config/refinement.conf:
    - EMBEDDING_MODEL (default: sentence-transformers/all-MiniLM-L6-v2)
    - TOP_K_RESULTS (default: 5)
    - SIMILARITY_THRESHOLD (default: 0.70)
    - CONTEXT_RETRIEVAL_TIMEOUT (default: 2000ms)
    - ENABLE_GRACEFUL_DEGRADATION (default: true)

Storage:
    Embedding index stored at: .docs/agents/shared/embeddings/index.pkl

Usage:
    from sdd.context.retriever import ContextRetriever

    retriever = ContextRetriever()

    # Retrieve relevant specs
    results = retriever.retrieve_relevant_specs(
        query="user authentication with JWT tokens",
        top_k=5
    )
    for result in results:
        print(f"{result['path']}: {result['similarity']:.3f}")

    # Retrieve similar tasks
    tasks = retriever.retrieve_similar_tasks(
        query="implement REST API endpoints"
    )

    # Retrieve architecture decisions
    decisions = retriever.retrieve_decisions(
        query="database schema design patterns"
    )
"""

import hashlib
import logging
import pickle
import re
import time
from collections import Counter
from datetime import datetime
from math import log, sqrt
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# Configure structured logging (Principle VII)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# ===================================================================
# TF-IDF Keyword Search (Fallback)
# ===================================================================

class TFIDFSearch:
    """
    Simple TF-IDF based keyword search (fallback when embeddings unavailable).

    Provides fast keyword-based similarity matching without external dependencies.
    """

    def __init__(self):
        """Initialize TF-IDF search."""
        self.documents: List[Dict[str, Any]] = []
        self.idf_scores: Dict[str, float] = {}

    def _tokenize(self, text: str) -> List[str]:
        """Tokenize text into lowercase words."""
        return re.findall(r'\b\w+\b', text.lower())

    def _compute_tf(self, tokens: List[str]) -> Dict[str, float]:
        """Compute term frequency."""
        counter = Counter(tokens)
        total = len(tokens)
        return {term: count / total for term, count in counter.items()}

    def _compute_idf(self) -> None:
        """Compute inverse document frequency."""
        doc_count = len(self.documents)
        term_doc_count: Dict[str, int] = {}

        for doc in self.documents:
            unique_terms = set(doc['tokens'])
            for term in unique_terms:
                term_doc_count[term] = term_doc_count.get(term, 0) + 1

        self.idf_scores = {
            term: log(doc_count / (count + 1))
            for term, count in term_doc_count.items()
        }

    def add_document(self, path: str, content: str) -> None:
        """Add document to index."""
        tokens = self._tokenize(content)
        self.documents.append({
            'path': path,
            'content': content,
            'tokens': tokens,
            'tf': self._compute_tf(tokens)
        })

    def build_index(self) -> None:
        """Build IDF scores after all documents added."""
        self._compute_idf()

    def search(self, query: str, top_k: int = 5) -> List[Dict[str, Any]]:
        """
        Search for similar documents using TF-IDF.

        Args:
            query: Search query
            top_k: Number of results to return

        Returns:
            List of {path, content, similarity} dicts
        """
        query_tokens = self._tokenize(query)
        query_tf = self._compute_tf(query_tokens)

        # Compute TF-IDF vectors
        results = []
        for doc in self.documents:
            # Compute cosine similarity
            dot_product = 0.0
            query_norm = 0.0
            doc_norm = 0.0

            all_terms = set(query_tf.keys()) | set(doc['tf'].keys())

            for term in all_terms:
                idf = self.idf_scores.get(term, 0.0)
                query_tfidf = query_tf.get(term, 0.0) * idf
                doc_tfidf = doc['tf'].get(term, 0.0) * idf

                dot_product += query_tfidf * doc_tfidf
                query_norm += query_tfidf ** 2
                doc_norm += doc_tfidf ** 2

            if query_norm > 0 and doc_norm > 0:
                similarity = dot_product / (sqrt(query_norm) * sqrt(doc_norm))
            else:
                similarity = 0.0

            results.append({
                'path': doc['path'],
                'content': doc['content'],
                'similarity': similarity
            })

        # Sort by similarity (descending)
        results.sort(key=lambda x: x['similarity'], reverse=True)
        return results[:top_k]


# ===================================================================
# ContextRetriever
# ===================================================================

class ContextRetriever:
    """
    Context Retriever for semantic codebase search.

    Uses sentence-transformers for semantic similarity (if available),
    falls back to TF-IDF keyword search if embeddings unavailable or slow.

    Attributes:
        config_path: Path to refinement.conf
        embeddings_dir: Directory for embedding index storage
        cache_dir: Directory for embedding cache
        config: Loaded configuration
        embedding_model: Sentence-transformers model (if available)
        use_embeddings: Whether to use embeddings (vs TF-IDF fallback)
        tfidf_search: TF-IDF search instance (fallback)
        index_updated: Timestamp of last index update
    """

    def __init__(
        self,
        config_path: str = "/workspaces/logic-loom/.logic-loom/config/refinement.conf",
        embeddings_dir: str = "/workspaces/logic-loom/.docs/agents/shared/embeddings",
        cache_dir: str = "/workspaces/logic-loom/.docs/agents/shared/embeddings/cache"
    ):
        """
        Initialize Context Retriever.

        Args:
            config_path: Path to refinement.conf
            embeddings_dir: Directory for embedding index
            cache_dir: Directory for embedding cache
        """
        self.config_path = Path(config_path)
        self.embeddings_dir = Path(embeddings_dir)
        self.cache_dir = Path(cache_dir)

        # Create directories
        self.embeddings_dir.mkdir(parents=True, exist_ok=True)
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        # Load configuration
        self.config = self._load_config()
        self.top_k = int(self.config.get("TOP_K_RESULTS", 5))
        self.similarity_threshold = float(self.config.get("SIMILARITY_THRESHOLD", 0.70))
        self.timeout_ms = int(self.config.get("CONTEXT_RETRIEVAL_TIMEOUT", 2000))
        self.enable_degradation = self.config.get("ENABLE_GRACEFUL_DEGRADATION", "true").lower() == "true"

        # Try to load sentence-transformers model
        self.embedding_model = None
        self.use_embeddings = False
        self._try_load_embeddings_model()

        # Initialize TF-IDF search (fallback)
        self.tfidf_search = TFIDFSearch()

        # Index state
        self.index_updated: Optional[datetime] = None
        self.documents: List[Dict[str, Any]] = []

        logger.info(
            f"ContextRetriever initialized: use_embeddings={self.use_embeddings}, "
            f"timeout_ms={self.timeout_ms}, top_k={self.top_k}"
        )

    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from refinement.conf."""
        if not self.config_path.exists():
            logger.warning(f"Config file not found: {self.config_path}, using defaults")
            return {}

        config = {}
        with open(self.config_path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' in line:
                    key, value = line.split('=', 1)
                    config[key.strip()] = value.strip().strip('"')

        return config

    def _try_load_embeddings_model(self) -> None:
        """Try to load sentence-transformers model (graceful degradation)."""
        try:
            from sentence_transformers import SentenceTransformer

            model_name = self.config.get("EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
            logger.info(f"Loading embedding model: {model_name}")

            # Try to load model with timeout
            start = time.time()
            self.embedding_model = SentenceTransformer(model_name)
            duration = time.time() - start

            if duration > self.timeout_ms / 1000.0:
                logger.warning(
                    f"Embedding model load took {duration:.2f}s (> {self.timeout_ms/1000}s timeout). "
                    f"Falling back to TF-IDF."
                )
                self.embedding_model = None
                self.use_embeddings = False
            else:
                self.use_embeddings = True
                logger.info(f"Embedding model loaded successfully in {duration:.2f}s")

        except ImportError:
            logger.warning(
                "sentence-transformers not available. Install with: pip install sentence-transformers. "
                "Falling back to TF-IDF keyword search."
            )
            self.use_embeddings = False
        except Exception as e:
            logger.warning(f"Failed to load embedding model: {e}. Falling back to TF-IDF.")
            self.use_embeddings = False

    def build_index(
        self,
        specs_dir: str = "/workspaces/logic-loom/specs",
        docs_dir: str = "/workspaces/logic-loom/.docs"
    ) -> None:
        """
        Build search index from specifications and documentation.

        Scans directories for .md files and indexes their content.

        Args:
            specs_dir: Directory containing feature specifications
            docs_dir: Directory containing documentation

        Example:
            >>> retriever = ContextRetriever()
            >>> retriever.build_index()
            >>> # Index is now ready for queries
        """
        logger.info(f"Building index from {specs_dir} and {docs_dir}")
        start_time = time.time()

        self.documents = []

        # Index specs
        specs_path = Path(specs_dir)
        if specs_path.exists():
            for md_file in specs_path.rglob("*.md"):
                self._index_file(md_file)

        # Index docs
        docs_path = Path(docs_dir)
        if docs_path.exists():
            for md_file in docs_path.rglob("*.md"):
                self._index_file(md_file)

        # Build TF-IDF index (always, as fallback)
        for doc in self.documents:
            self.tfidf_search.add_document(doc['path'], doc['content'])
        self.tfidf_search.build_index()

        # Save index
        self._save_index()

        duration = time.time() - start_time
        self.index_updated = datetime.now()

        logger.info(
            f"Index built: {len(self.documents)} documents in {duration:.2f}s. "
            f"Method: {'embeddings' if self.use_embeddings else 'TF-IDF'}"
        )

    def _index_file(self, file_path: Path) -> None:
        """Index a single file."""
        try:
            content = file_path.read_text(encoding='utf-8')
            self.documents.append({
                'path': str(file_path),
                'content': content,
                'indexed_at': datetime.now().isoformat()
            })
            logger.debug(f"Indexed: {file_path}")
        except Exception as e:
            logger.warning(f"Failed to index {file_path}: {e}")

    def retrieve_relevant_specs(
        self,
        query: str,
        top_k: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """
        Retrieve relevant specifications for query.

        Args:
            query: Search query
            top_k: Number of results (default: from config)

        Returns:
            List of {path, content, similarity} dicts

        Example:
            >>> retriever = ContextRetriever()
            >>> retriever.build_index()
            >>> results = retriever.retrieve_relevant_specs(
            ...     "user authentication with JWT"
            ... )
            >>> for r in results:
            ...     print(f"{r['path']}: {r['similarity']:.3f}")
        """
        if top_k is None:
            top_k = self.top_k

        # Ensure index is built
        if not self.documents:
            logger.warning("Index not built. Building now...")
            self.build_index()

        # Measure query time
        start = time.time()

        # Use embeddings if available and fast
        if self.use_embeddings and self.embedding_model:
            try:
                results = self._search_with_embeddings(query, top_k)
                duration_ms = (time.time() - start) * 1000

                if duration_ms > self.timeout_ms and self.enable_degradation:
                    logger.warning(
                        f"Embedding search took {duration_ms:.0f}ms (> {self.timeout_ms}ms). "
                        f"Falling back to TF-IDF."
                    )
                    self.use_embeddings = False  # Disable for future queries
                    return self._search_with_tfidf(query, top_k)

                logger.info(f"Embedding search completed in {duration_ms:.0f}ms")
                return results

            except Exception as e:
                logger.warning(f"Embedding search failed: {e}. Falling back to TF-IDF.")
                return self._search_with_tfidf(query, top_k)

        # Use TF-IDF fallback
        return self._search_with_tfidf(query, top_k)

    def retrieve_similar_tasks(
        self,
        query: str,
        top_k: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """
        Retrieve similar tasks based on query.

        Args:
            query: Search query describing task
            top_k: Number of results

        Returns:
            List of {path, content, similarity} dicts
        """
        # Filter to tasks.md files only
        results = self.retrieve_relevant_specs(query, top_k)
        return [r for r in results if 'tasks.md' in r['path']]

    def retrieve_decisions(
        self,
        query: str,
        top_k: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """
        Retrieve architecture decisions based on query.

        Args:
            query: Search query
            top_k: Number of results

        Returns:
            List of {path, content, similarity} dicts
        """
        # Filter to decision/architecture docs
        results = self.retrieve_relevant_specs(query, top_k)
        return [r for r in results if any(
            keyword in r['path'].lower()
            for keyword in ['decision', 'architecture', 'adr', 'design']
        )]

    def _search_with_embeddings(
        self,
        query: str,
        top_k: int
    ) -> List[Dict[str, Any]]:
        """Search using sentence-transformers embeddings."""
        if not self.embedding_model:
            raise RuntimeError("Embedding model not available")

        # Generate query embedding
        query_embedding = self.embedding_model.encode([query])[0]

        # Generate document embeddings (with caching)
        doc_embeddings = []
        for doc in self.documents:
            embedding = self._get_cached_embedding(doc['path'], doc['content'])
            doc_embeddings.append(embedding)

        # Compute cosine similarities
        results = []
        for i, doc in enumerate(self.documents):
            similarity = self._cosine_similarity(query_embedding, doc_embeddings[i])
            if similarity >= self.similarity_threshold:
                results.append({
                    'path': doc['path'],
                    'content': doc['content'],
                    'similarity': float(similarity)
                })

        # Sort by similarity (descending)
        results.sort(key=lambda x: x['similarity'], reverse=True)
        return results[:top_k]

    def _search_with_tfidf(
        self,
        query: str,
        top_k: int
    ) -> List[Dict[str, Any]]:
        """Search using TF-IDF keyword matching."""
        return self.tfidf_search.search(query, top_k)

    def _get_cached_embedding(self, path: str, content: str) -> Any:
        """Get cached embedding or compute and cache it."""
        # Generate cache key
        content_hash = hashlib.md5(content.encode()).hexdigest()
        cache_key = f"{Path(path).stem}_{content_hash}"
        cache_file = self.cache_dir / f"{cache_key}.pkl"

        # Check cache
        if cache_file.exists():
            with open(cache_file, 'rb') as f:
                return pickle.load(f)

        # Compute embedding
        embedding = self.embedding_model.encode([content])[0]

        # Cache it
        with open(cache_file, 'wb') as f:
            pickle.dump(embedding, f)

        return embedding

    def _cosine_similarity(self, a: Any, b: Any) -> float:
        """Compute cosine similarity between two vectors."""
        import numpy as np
        return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))

    def _save_index(self) -> None:
        """Save index to disk."""
        index_file = self.embeddings_dir / "index.pkl"
        index_data = {
            'documents': self.documents,
            'updated_at': datetime.now().isoformat(),
            'use_embeddings': self.use_embeddings
        }

        with open(index_file, 'wb') as f:
            pickle.dump(index_data, f)

        logger.info(f"Index saved: {index_file}")

    def load_index(self) -> bool:
        """
        Load index from disk.

        Returns:
            True if loaded successfully, False otherwise
        """
        index_file = self.embeddings_dir / "index.pkl"
        if not index_file.exists():
            return False

        try:
            with open(index_file, 'rb') as f:
                index_data = pickle.load(f)

            self.documents = index_data['documents']
            self.index_updated = datetime.fromisoformat(index_data['updated_at'])

            # Rebuild TF-IDF index
            for doc in self.documents:
                self.tfidf_search.add_document(doc['path'], doc['content'])
            self.tfidf_search.build_index()

            logger.info(
                f"Index loaded: {len(self.documents)} documents, "
                f"updated: {self.index_updated}"
            )
            return True

        except Exception as e:
            logger.warning(f"Failed to load index: {e}")
            return False
