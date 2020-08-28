#!/bin/bash

echo "Repository: [$GITHUB_REPOSITORY]"

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
PULL_REQUEST="$INPUT_PULL_REQUEST"
echo "Pull request    : $PULL_REQUEST"

# set temp path
TEMP_PATH="/ghafs/"
cd /
mkdir "$TEMP_PATH"
cd "$TEMP_PATH"
echo "Temp Path       : $TEMP_PATH"
echo "---------------------------------------------"

echo " "

# initalize git
echo "Intiializing git"
git config --system core.longpaths true
git config --global core.longpaths true
git config --global user.email "action-bot@github.com" && git config --global user.name "Github Action"
echo "Git initialized"

echo " "

# loop through all the repos
for repository in "${REPOSITORIES[@]}"; do
    echo "###[group] $repository"

    # determine repo name
    REPO_INFO=($(echo $repository | tr "@" "\n"))
    REPO_NAME=${REPO_INFO[0]}
    echo "Repository name: [$REPO_NAME]"
    
    # determine branch name
    BRANCH_NAME="master"
    if [ ${REPO_INFO[1]+yes} ]; then
        BRANCH_NAME="${REPO_INFO[1]}"
    fi
    echo "Branch: [$BRANCH_NAME]"

    # clone the repo
    REPO_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_NAME}.git"
    GIT_PATH="${TEMP_PATH}${REPO_NAME}"
    echo "Cloning [$REPO_URL] to [$GIT_PATH]"
    git clone --quiet --no-hardlinks --no-tags --depth 1 $REPO_URL $REPO_NAME

    cd $GIT_PATH

    # checkout the branch, if specified
    if [ "$BRANCH_NAME" != "master" ]; then
        # try to check out the origin, if fails, then create the local branch
        git fetch && git checkout $BRANCH_NAME && git pull || git checkout -b $BRANCH_NAME
    fi

    echo " "
  
    # loop through all files
    for file in "${FILES[@]}"; do
        echo "File: [${file}]"
        # split and trim
        FILE_TO_SYNC=($(echo $file | tr "=" "\n"))
        SOURCE_PATH=${FILE_TO_SYNC[0]}
        echo "Source path: [$SOURCE_PATH]"
        
        # initialize the full path
        SOURCE_FULL_PATH="${GITHUB_WORKSPACE}/${SOURCE_PATH}"
        echo "Source full path: [$SOURCE_FULL_PATH]"

        # set the default of source and destination path the same
        SOURCE_FILE_NAME=$(basename "$SOURCE_PATH")
        echo "Source file name: [$SOURCE_FILE_NAME]"
        DEST_PATH="${SOURCE_FILE_NAME}"
        echo "Destination file path: [$DEST_PATH]"

        # if destination is different, then set it
        if [ ${FILE_TO_SYNC[1]+yes} ]; then
            DEST_PATH="${FILE_TO_SYNC[1]}"
            echo "Destination file path specified: [$DEST_PATH]"
        fi

        # check that source full path isn't null
        if [ "$SOURCE_FULL_PATH" != "" ]; then
            # test path to copy to
            DEST_FULL_PATH="${GIT_PATH}/${DEST_PATH}"
            DEST_FOLDER_PATH=$(dirname "$DEST_FULL_PATH")
            if [ ! -d "$DEST_FOLDER_PATH" ]; then
                echo "Creating [$DEST_FOLDER_PATH]"
                mkdir -p $DEST_FOLDER_PATH
            fi

            # copy file
            echo "Copying: [$SOURCE_FULL_PATH] to [$DEST_FULL_PATH]"
            SP_TRIM="$(echo -e "${SOURCE_FULL_PATH}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            DP_TRIM="$(echo -e "${DEST_FULL_PATH}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            echo "Trimmed source path: [${SP_TRIM}]"
            echo "Trimmed destination path: [${DP_TRIM}]"
            cp "${SP_TRIM}" "${DP_TRIM}"
            
            # add file
            git add "${DEST_FULL_PATH}" -f

            # check if anything is new
            if [ "$(git status --porcelain)" != "" ]; then
                echo "Committing changes"
                git commit -m "File sync from ${GITHUB_REPOSITORY}"
            else
                echo "Files not changed: [${SOURCE_FILE_NAME}]"
            fi
        else
            echo "[${SOURCE_FULL_PATH}] not found in [${GITHUB_REPOSITORY}]"
        fi
        echo " "
    done

    cd ${GIT_PATH}

    # push changes
    echo "Push changes to [${REPO_URL}]"
    git push $REPO_URL
    if [ "$BRANCH_NAME" != "master" -a "$PULL_REQUEST" == "true" ]; then
        echo "Creating pull request"
        jq -n --arg title "File sync from ${GITHUB_REPOSITORY}" --arg head "$BRANCH_NAME" --arg base "master" '{title:$title,head:$head,base:$base}' | curl -d @- \
            -X POST \
            -H "Accept: application/vnd.github.v3+json" \
            -u ${USERNAME}:${GITHUB_TOKEN} \
            --silent \
            ${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/pulls
    fi
    cd $TEMP_PATH
    rm -rf $REPO_NAME
    echo "Completed [${REPO_NAME}]"
    echo "###[endgroup]"
done