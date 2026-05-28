#!/usr/bin/env node
// Simple JSON parser helper for bash scripts (replaces jq on systems without it)
// Usage: node json-parse.js <json_string_or_file> <query>
// Examples:
//   node json-parse.js '{"version":"1.0"}' '.version'
//   node json-parse.js '{"data":{"name":"test"}}' '.data.name'
//   echo '{"test":1}' | node json-parse.js - '.test'

const fs = require('fs');

// Get arguments
const args = process.argv.slice(2);

if (args.length < 2) {
    console.error('Usage: node json-parse.js <json_string_or_file_or_-> <query>');
    process.exit(1);
}

let jsonInput = args[0];
const query = args[1];

// Handle stdin (-)
if (jsonInput === '-' || jsonInput === '/dev/stdin') {
    // Read from stdin synchronously
    jsonInput = fs.readFileSync(0, 'utf8');
} else if (fs.existsSync(jsonInput)) {
    // If first arg is a file, read it
    try {
        jsonInput = fs.readFileSync(jsonInput, 'utf8');
    } catch (err) {
        console.error(`Error reading file: ${err.message}`);
        process.exit(1);
    }
}

// Parse JSON
let data;
try {
    data = JSON.parse(jsonInput);
} catch (err) {
    console.error(`Invalid JSON: ${err.message}`);
    process.exit(1);
}

// Parse query (simple dot notation)
// Supports: .field, .field.nested, .array[0], etc.
function queryData(obj, path) {
    if (path === '.' || path === '') {
        return obj;
    }

    // Remove leading dot
    if (path.startsWith('.')) {
        path = path.substring(1);
    }

    const parts = path.split('.');
    let current = obj;

    for (const part of parts) {
        // Handle array access: field[0]
        const arrayMatch = part.match(/^(\w+)\[(\d+)\]$/);
        if (arrayMatch) {
            const [, field, index] = arrayMatch;
            current = current[field];
            if (Array.isArray(current)) {
                current = current[parseInt(index)];
            } else {
                return null;
            }
        } else {
            // Regular field access
            if (current === null || current === undefined) {
                return null;
            }
            current = current[part];
        }
    }

    return current;
}

// Execute query
const result = queryData(data, query);

// Output result
if (result === null || result === undefined) {
    console.log('null');
} else if (typeof result === 'object') {
    console.log(JSON.stringify(result));
} else {
    console.log(result);
}
