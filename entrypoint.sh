#!/bin/bash

echo "Repository: $1"

# log inputs
echo "Inputs"
echo "---------------------------------------------"
RAW_REPOSITORIES="$INPUT_REPOSITORIES"
RAW_FILES="$INPUT_FILES"
GITHUB_TOKEN="$INPUT_TOKEN"
REPOSITORIES=($RAW_REPOSITORIES)
echo "Repositories    : $REPOSITORIES"
FILES=($RAW_FILES)
echo "Files           : $FILES"

# set temp path
TEMP_PATH="/ghafs/"
cd /
mkdir "$TEMP_PATH"
cd "$TEMP_PATH"
echo "Temp Path       : $TEMP_PATH"
echo "---------------------------------------------"

# initalize git
echo "Intiializing git"
git config --system core.longpaths true
git config --global core.longpaths true
git config --global user.email "action-bot@github.com" && git config --global user.name "Github Action"
echo "Git initialized"

loop through all the repos
for repository in "${REPOSITORIES[@]}"; do
    echo "###[group] $repository"

    # clone the repo
    REPO_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${repository}.git"
    GIT_PATH="${TEMP_PATH}${repository}"
    echo "Cloning $REPO_URL to $GIT_PATH"
    git clone --quiet --no-hardlinks --no-tags --depth 1 $REPO_URL ${repository}
    echo "Cloned"

    cd $GIT_PATH
  
    # loop through all files
    for file in "${FILES[@]}"; do
        # split and trim
        FILE_TO_SYNC=($(echo $file | tr "=" "\n"))
        echo "File to sync: $FILE_TO_SYNC"
        
        # array at 0 is the path
        SOURCE_FILE=${FILE_TO_SYNC[0]}
        echo "Source file: $SOURCE_FILE"
        
        # initialize the full path
        SOURCE_FULL_PATH="${GITHUB_WORKSPACE}/${SOURCE_FILE}"
        echo "Source full path: $SOURCE_FULL_PATH"

        # set the default of source and destination path the same
        SOURCE_FILE_NAME=$(basename "$SOURCE_FILE")
        echo "Source file name: $SOURCE_FILE_NAME"
        DEST_FILE="${SOURCE_FILE_NAME}"
        echo "Destination file name: $DEST_FILE"

        # if destination is different, then set it
        if [ ${FILE_TO_SYNC[1]+yes} ]; then
            DEST_FILE="${FILE_TO_SYNC[1]}"
            echo "Destination file updated: $DEST_FILE"
        fi

        # check that source full path isn't null
        if [ "$SOURCE_FULL_PATH" != "" ]; then
            # test local path
            LOCAL_PATH="${GIT_PATH}"
            echo "Local path: $LOCAL_PATH"
            if [ ! -d "$LOCAL_PATH" ]; then
                mkdir -p $LOCAL_PATH
            fi
            
            # copy file
            DEST_FULL_PATH="${LOCAL_PATH}/${DEST_FILE}"
            echo "Copying: $SOURCE_FULL_PATH to $DEST_FULL_PATH"
            cp "$SOURCE_FULL_PATH" "${DEST_FULL_PATH}"
            
            # add file
            echo "Git add for $DEST_FULL_PATH"
            git add "${DEST_FULL_PATH}" -f

            # check if anything is new
            if [ "$(git status --porcelain)" != "" ]; then
                echo "Committing changes"
                git commit -m "File sync from ${GITHUB_REPOSITORY}"
                echo "Committed"
            else
                echo "Files not changed: ${SOURCE_FILE}"
            fi
        else
            echo "${SOURCE_FULL_PATH} not found in ${GITHUB_REPOSITORY}"
        fi
        echo " "
    done

    cd ${GIT_PATH}

    # push changes
    echo "Push changes to ${REPO_URL}"
    git push $REPO_URL
    cd $TEMP_PATH
    echo "###[endgroup]"
    echo "Completed $repository"
done