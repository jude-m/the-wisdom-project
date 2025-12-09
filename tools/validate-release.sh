#!/bin/bash
#
# Comprehensive pre-release checklist for The Wisdom Project
# Runs all validations, tests, and checks before building a release
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the project root directory (parent of tools/)
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo ""
echo "=========================================="
echo "  The Wisdom Project"
echo "  Pre-Release Validation"
echo "=========================================="
echo ""

# Track failures
FAILED=0

# Function to print step header
print_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Function to handle errors
handle_error() {
    echo -e "${RED}✗ FAILED: $1${NC}"
    FAILED=1
}

# Change to project root
cd "$PROJECT_ROOT"

# Step 1: Validate FTS database
print_step "Step 1: Validating FTS Database"

DB_PATH="$PROJECT_ROOT/assets/databases/bjt-fts.db"

# Check if the FTS database exists
if [ ! -f "$DB_PATH" ]; then
    echo -e "${RED}✗ ERROR: FTS database not found!${NC}"
    echo "  Expected location: $DB_PATH"
    echo ""
    echo "To generate the database:"
    echo "  cd tools && npm install && npm run generate-fts"
    handle_error "FTS database not found"
    exit 1
fi

# Check database size (should be around 114 MB)
DB_SIZE=$(stat -f%z "$DB_PATH" 2>/dev/null || stat -c%s "$DB_PATH" 2>/dev/null)
DB_SIZE_MB=$((DB_SIZE / 1024 / 1024))

if [ "$DB_SIZE_MB" -lt 50 ]; then
    echo -e "${RED}✗ ERROR: Database file is too small (${DB_SIZE_MB} MB)${NC}"
    echo "  Expected: ~114 MB | Actual: ${DB_SIZE_MB} MB"
    echo "  The database may be corrupted. Regenerate it:"
    echo "  cd tools && npm run generate-fts"
    handle_error "Database size validation failed"
    exit 1
fi

echo -e "${GREEN}✓ FTS database found (${DB_SIZE_MB} MB)${NC}"

# Check if pubspec.yaml includes the database
if ! grep -q "assets/databases/bjt-fts.db" "$PROJECT_ROOT/pubspec.yaml"; then
    echo -e "${YELLOW}⚠ WARNING: pubspec.yaml may not include the database${NC}"
    echo "Make sure pubspec.yaml contains: assets/databases/bjt-fts.db"
    handle_error "Database not in pubspec.yaml"
fi

echo -e "${GREEN}✓ pubspec.yaml includes database${NC}"

# Step 2: Run code generation
print_step "Step 2: Running Code Generation"
echo "Running: dart run build_runner build --delete-conflicting-outputs"
if dart run build_runner build --delete-conflicting-outputs; then
    echo -e "${GREEN}✓ Code generation completed${NC}"
else
    handle_error "Code generation failed"
fi

# Step 3: Run Flutter analyzer
print_step "Step 3: Running Flutter Analyzer"
echo "Running: flutter analyze"
if flutter analyze; then
    echo -e "${GREEN}✓ No analyzer issues found${NC}"
else
    handle_error "Flutter analyzer found issues"
fi

# Step 4: Check code formatting
print_step "Step 4: Checking Code Formatting"
echo "Running: dart format lib/ test/ --set-exit-if-changed"
if dart format lib/ test/ --set-exit-if-changed > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Code is properly formatted${NC}"
else
    echo -e "${YELLOW}⚠ Code formatting issues found${NC}"
    echo "Run: dart format lib/ test/"
    handle_error "Code formatting check failed"
fi

# Step 5: Run unit and widget tests
print_step "Step 5: Running Unit & Widget Tests"
echo "Running: flutter test"
if flutter test; then
    echo -e "${GREEN}✓ All unit and widget tests passed${NC}"
else
    handle_error "Unit/widget tests failed"
fi

# Step 6: Run integration tests
print_step "Step 6: Running Integration Tests"
if [ -d "integration_test" ] && [ "$(ls -A integration_test/*.dart 2>/dev/null)" ]; then
    echo "Running: flutter test integration_test/"
    if flutter test integration_test/; then
        echo -e "${GREEN}✓ All integration tests passed${NC}"
    else
        handle_error "Integration tests failed"
    fi
else
    echo -e "${YELLOW}⚠ No integration tests found (integration_test/ directory empty or missing)${NC}"
fi

# Step 7: Final Summary
print_step "Pre-Release Validation Summary"

if [ $FAILED -eq 1 ]; then
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ VALIDATION FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Please fix the issues above before building a release."
    echo ""
    exit 1
else
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ ALL CHECKS PASSED${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Your code is ready for release!"
    echo ""
    echo "Next steps:"
    echo "  1. Test the app locally"
    echo "  2. Build for your target platform:"
    echo "     - flutter build apk"
    echo "     - flutter build appbundle"
    echo "     - flutter build ios"
    echo ""
    exit 0
fi
