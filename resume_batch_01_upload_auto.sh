#!/bin/bash

# Resume script to continue batch_01 upload from subbatch 44
# This continues where the previous upload was interrupted
# NON-INTERACTIVE VERSION for nohup

set -e  # Exit on any error

BATCH_DIR="images/batch_01"
SUBBATCH_SIZE=100
START_SUBBATCH=44  # Resume from subbatch 44

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if batch_01 directory exists
if [ ! -d "$BATCH_DIR" ]; then
    print_error "Directory $BATCH_DIR does not exist!"
    exit 1
fi

# Get sorted list of all subdirectories
SUBDIRS=($(ls -1 "$BATCH_DIR" | sort -n))
TOTAL_DIRS=${#SUBDIRS[@]}

print_status "Found $TOTAL_DIRS subdirectories in $BATCH_DIR"
print_status "Auto-resuming from subbatch $START_SUBBATCH (non-interactive mode)"

# Calculate number of subbatches needed
TOTAL_SUBBATCHES=$(( (TOTAL_DIRS + SUBBATCH_SIZE - 1) / SUBBATCH_SIZE ))
REMAINING_SUBBATCHES=$((TOTAL_SUBBATCHES - START_SUBBATCH + 1))

print_status "Total subbatches needed: $TOTAL_SUBBATCHES"
print_status "Remaining subbatches to upload: $REMAINING_SUBBATCHES"

echo
echo "=== AUTO-RESUME STARTING ==="
echo "Last completed: subbatch 43/98"
echo "Resuming from: subbatch $START_SUBBATCH/98"
echo "Remaining: $REMAINING_SUBBATCHES subbatches"
echo "Starting upload automatically..."
echo "=========================="
echo

# Process each subbatch starting from START_SUBBATCH
for ((i=$((START_SUBBATCH-1)); i<TOTAL_SUBBATCHES; i++)); do
    SUBBATCH_NUM=$((i + 1))
    START_IDX=$((i * SUBBATCH_SIZE))
    END_IDX=$(((i + 1) * SUBBATCH_SIZE - 1))
    
    # Adjust end index for last batch
    if [ $END_IDX -ge $TOTAL_DIRS ]; then
        END_IDX=$((TOTAL_DIRS - 1))
    fi
    
    CURRENT_BATCH_SIZE=$((END_IDX - START_IDX + 1))
    
    print_status "Processing subbatch $SUBBATCH_NUM/$TOTAL_SUBBATCHES (dirs $START_IDX-$END_IDX, $CURRENT_BATCH_SIZE directories)"
    
    # Add directories for this subbatch
    for ((j=START_IDX; j<=END_IDX; j++)); do
        SUBDIR="${SUBDIRS[$j]}"
        git add "$BATCH_DIR/$SUBDIR/"
    done
    
    # Count files in this subbatch
    FILE_COUNT=0
    for ((j=START_IDX; j<=END_IDX; j++)); do
        SUBDIR="${SUBDIRS[$j]}"
        SUBDIR_FILES=$(find "$BATCH_DIR/$SUBDIR" -type f | wc -l)
        FILE_COUNT=$((FILE_COUNT + SUBDIR_FILES))
    done
    
    # Create commit message
    FIRST_DIR="${SUBDIRS[$START_IDX]}"
    LAST_DIR="${SUBDIRS[$END_IDX]}"
    
    COMMIT_MSG="Add batch_01 subbatch $SUBBATCH_NUM/$TOTAL_SUBBATCHES (dirs $FIRST_DIR-$LAST_DIR) - Contains $FILE_COUNT files in $CURRENT_BATCH_SIZE directories"
    
    # Commit this subbatch
    git commit -m "$COMMIT_MSG"
    print_success "Committed subbatch $SUBBATCH_NUM with $FILE_COUNT files"
    
    # Push this subbatch
    print_status "Pushing subbatch $SUBBATCH_NUM to GitHub..."
    
    # Try pushing with retries
    PUSH_ATTEMPTS=3
    PUSH_SUCCESS=false
    
    for attempt in $(seq 1 $PUSH_ATTEMPTS); do
        print_status "Push attempt $attempt/$PUSH_ATTEMPTS for subbatch $SUBBATCH_NUM"
        
        if git push origin main; then
            print_success "Successfully pushed subbatch $SUBBATCH_NUM"
            PUSH_SUCCESS=true
            break
        else
            print_warning "Push attempt $attempt failed for subbatch $SUBBATCH_NUM"
            if [ $attempt -lt $PUSH_ATTEMPTS ]; then
                print_status "Waiting 30 seconds before retry..."
                sleep 30
            fi
        fi
    done
    
    if [ "$PUSH_SUCCESS" = false ]; then
        print_error "Failed to push subbatch $SUBBATCH_NUM after $PUSH_ATTEMPTS attempts"
        print_error "You can manually retry with: git push origin main"
        exit 1
    fi
    
    # Small delay between subbatches to be gentle on GitHub
    if [ $SUBBATCH_NUM -lt $TOTAL_SUBBATCHES ]; then
        print_status "Waiting 10 seconds before next subbatch..."
        sleep 10
    fi
    
    echo "----------------------------------------"
done

# Final summary
print_success "Resume upload completed!"
print_success "Completed subbatches: $START_SUBBATCH to $TOTAL_SUBBATCHES"
print_success "Total directories: $TOTAL_DIRS"

# Verify final state
TOTAL_COMMITS=$(git rev-list --count HEAD)
print_success "Repository now has $TOTAL_COMMITS total commits"
print_success "batch_01 upload completed successfully!"

echo
echo "==================== RESUME UPLOAD SUMMARY ===================="
echo "✅ batch_01 directories: $TOTAL_DIRS"
echo "✅ Resumed from subbatch: $START_SUBBATCH"
echo "✅ Completed subbatches: $((TOTAL_SUBBATCHES - START_SUBBATCH + 1))"
echo "✅ All remaining subbatches pushed to GitHub"
echo "✅ Repository: https://github.com/$(git config user.name)/mentis-data-public"
echo "=================================================================" 