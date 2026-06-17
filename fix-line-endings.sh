#!/bin/bash

# NOTE: ONE-TIME UTILITY — only needed if CRLF errors occur on Windows.
# This is not part of the regular workflow.

# Emergency line ending fixer for LogicLoom
# Run this if you encounter CRLF errors when trying to run setup

echo "======================================"
echo "   Fixing Script Line Endings"
echo "======================================"
echo ""

# Fix all bash scripts
echo "Fixing bash scripts (.sh files)..."
find .logic-loom/scripts -name "*.sh" -type f 2>/dev/null | while read file; do
    if [ -f "$file" ]; then
        # Remove carriage returns
        sed -i 's/\r$//' "$file" 2>/dev/null || sed -i '' 's/\r$//' "$file" 2>/dev/null
        echo "  Fixed: $file"
    fi
done

# Fix PowerShell scripts
echo ""
echo "Fixing PowerShell scripts (.ps1 files)..."
find .logic-loom/scripts -name "*.ps1" -type f 2>/dev/null | while read file; do
    if [ -f "$file" ]; then
        # Remove carriage returns
        sed -i 's/\r$//' "$file" 2>/dev/null || sed -i '' 's/\r$//' "$file" 2>/dev/null
        echo "  Fixed: $file"
    fi
done

# Make scripts executable
echo ""
echo "Making scripts executable..."
chmod +x .logic-loom/scripts/bash/*.sh 2>/dev/null
chmod +x .logic-loom/scripts/setup.sh 2>/dev/null
echo "  Done"

echo ""
echo "======================================"
echo "   Line Endings Fixed! ✓"
echo "======================================"
echo ""
echo "You can now run:"
echo "  bash .logic-loom/scripts/setup.sh"
echo ""
