# Bitnami support

This repository contains common workflows reusable from other repositories in the organization. Initially, most of these workflows have been created to manage the lifecycle of our support tasks.

The repository contains two types of workflows:
* Reusable workflows under `.github/workflows`
* Synced workflows under `workflows`

## Reusable workflows

These workflows are, and must be, under `.github/workflows` folder due to GitHub restrictions. These files were extracted from other repositories and they were created for especific events, for that reason we tried to follow this convention `<webhook>-<activity-type>` ([About events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#about-events-that-trigger-workflows)) to name them. The main goal of these workflows is manage the [Bitnami Project support board](https://github.com/orgs/bitnami/projects/4)

* [`comment-created.yml`](.github/workflows/comment-created.yml): Moves cards based on issue/pr comments. Also it adds the label `review-required` if the comment was added on automated PR by bitnami-bot.
* [`item-closed.yml`](.github/workflows/item-closed.yml): Sends cards to the Solved column and adds the `solved` label.
* [`item-labeled.yml`](.github/workflows/item-labeled.yml): Moves cards according to its labels. Also it reassigns tasks if it is needed, for instance, when we are labeling with `in-progress`.
* [`item-opened.yml`](.github/workflows/item-opened.yml): Creates the item card, puts it into the Triage column and assigns it to a Bitnami Team member.
* [`pr-review-requested-sync.yml`](.github/workflows/pr-review-requested-sync.yml): Moves the cards when a review is requested.

The [`.env` file](.env) plays an important role here. It has the following information used by previous workflows:
* BITNAMI_TEAM. Members of Bitnami Team. [Daily synced](.github/workflows/sync-teams.yml) with the [GitHub Bitnami Support Team](https://github.com/orgs/bitnami/teams/support)
* LABEL_MAPPING. All labels used by the workflows, the column associated and label to be removed when the label is set. The content of this variable is an array with that information for each label in json format, for example:
```json
"triage": {
  "column": "Triage",
  "labels-to-remove": [
    "in-progress",
    "on-hold",
    "solved"
  ]
}
```
* REPO_ASSIGNMENT. Each repository managed by these workflows could have its own assignment, for instance, charts and containers have their own teams to manage the support tasks. It contains triage and support assignments for each repository and a default one if the repository doesn't have any specific assignee.
```json
{
  "charts": {
    "triage-teams": "charts-triage",
    "support-teams": "charts-support"
  },
  "containers": {
    "triage-teams": "containers-triage",
    "support-teams": "containers-support"
  },
  "vms": {
    "triage-teams": "vms-triage",
    "support-teams": "vms-support"
  },
  "default": {
    "triage-assignees": "fmulero",
    "support-assginees": "fmulero"
  }
}
```

## Synced workflows

These workflows are located in `/workflows` and they are synced with the repositories configured in the [sync.yml](.github/sync.yml) file. Any change on this files will create a PR in those repositories. The main purpose of these files is to link the repository events with the reusable workflows described above.

## Migration workflow

This workflow copies existing cards from a repository Project (Classic) board into the new organization Project (ProjectV2) board, in our case we will use the [Bitnami Support board](https://github.com/orgs/bitnami/projects/4/views/1). To use it we only need to create workflow like this one in our repository:

```yaml
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

name: '[Support] Cards migration'
on: [ workflow_dispatch ]
jobs:
  call-migration-workflow:
    uses: bitnami/support/.github/workflows/migrate-reusable.yml@main
    with:
      organization: bitnami
      legacy_project_board_name: Support
      new_project_number: 4
      repo: ${{ github.event.repository.name }}
    secrets:
      # This token should have access to both projects and at least read:project permissions
      token: GITHUB_TOKEN
```

### How it works

The hard work is done by this [piece of code](.github/scripts/migrate.sh) but in general lines the process is easy:

1. Retrieve information about projects.
2. Loop over each Project (classic) column.
3. Get the cards from each column.
4. Create new cards in the new Project.
5. Move each new card to the right column.

NOTES:
* The process will migrate all cards in one execution.
* If you face any error you can trigger the workflow again, no duplications should occur in the target Project.
* If you have a significant number of cards you could reach GitHub thresholds, in that case you should remove/archive previously migrated cards in the source Project (classic) to reduce the number of requests.