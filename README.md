<h1 align="center">github-action-file-sync</h1>


<div align="center">

<b>Github Action to sync files across repos</b>

[![version](https://img.shields.io/github/v/release/kbrashears5/github-action-file-sync)](https://img.shields.io/github/v/release/kbrashears5/github-action-file-sync)

</div>


# Use Cases
Great for keeping your files in sync across multiple repositories. A good use case for me was the `.github/dependabot.yml` files.

I have a master repo where these are synced from, and then they are kept in sync with the master repository.

If I need to make a change, rather than go make a change x many times across all my repositories, I make the change once, and on push to the master repository, all my child repositories are updated. 

Another example is if you're creating new Github Actions for a repository, you can make them once, check them into master repository, and then deploy them all across all your repositories all at once. 

This also isn't limited to Github Action yaml files - another use case could be keeping the `.editorconfig`, `LICENSE`, `tsconfig.json`, `tslint.json`, `.gitignore`, `azure-pieplines.yml`, etc. in sync across all your repositories.

If I have a file that gets out of sync for whatever reason, the cron side of the `on` will take care of putting it back in sync with the master repository.

See my [master sync repo](https://github.com/kbrashears5/kbrashears5) for examples on how I use it across all my repositories.

# Setup
Create a new file called `/.github/workflows/file-sync.yml` that looks like so:
```yaml
name: File Sync

on:
  push:
    branches:
      - master
  schedule:
    - cron: 0 0 * * *

jobs:
  file_sync:
    runs-on: ubuntu-latest
    steps:
      - name: Fetching Local Repository
        uses: actions/checkout@master
      - name: File Sync
        uses: kbrashears5/github-action-file-sync@v2.0.0
        with:
          REPOSITORIES: |
            username/repo@master
          FILES: |
            sync/dependabot.yml=.github/dependabot.yml
          TOKEN: ${{ secrets.ACTIONS }}
```
## Parameters
| Parameter | Required | Description |
| --- | --- | --- |
| REPOSITORIES | true | List of repositories to sync the files to. Optionally provide branch name |
| FILES | true | List of files to sync across repositories. See below for details |
| TOKEN | true | Personal Access Token with Repo scope |
| PULL_REQUEST | false | Whether or not you want to do a pull request. Only works when branch name is provided. Default false |

## Examples
### REPOSITORIES parameter
Push to the `master` branch
```yaml
REPOSITORIES: |
    username/repo
```
Push to the `dev` branch
```yaml
REPOSITORIES: |
    username/repo@dev
```
### FILES parameter

<u>File sync</u>

Root file with root destination
```yaml
FILES: |
    dependabot.yml
```
Root file with new destination
```yaml
FILES: |
    dependabot.yml=.github/dependabot.yml
```
Nested file with same nested file structure destination
```yaml
FILES: |
    /.github/dependabot.yml
```
Nested file with new destination
```yaml
FILES: |
    /sync/dependabot.yml=.github/dependabot.yml
```

<u>Folder Sync</u>

Root folder to root directory
```yaml
FILES: |
    ./sync
```
Root folder with new directory
```yaml
FILES: |
    ./sync=newFolderName
```
### TOKEN parameter
Use the repository secret named `ACTIONS`
```yaml
TOKEN: ${{ secrets.ACTIONS }}
```

## Troubleshooting
Spacing around the equal sign is important. For example, this will not work:
```yaml
FILES: |
  folder/file-sync.yml = folder/test.txt
```
It passes to the shell file 3 distinct objects
- folder/file-sync.ymll
- =
- folder/test.txt

instead of 1 object

- folder/file-sync.yml = folder/test.txt

and there is nothing I can do in code to make up for that