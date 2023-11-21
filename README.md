# Bitnami support

This repository contains common workflows reusable from other repositories in the organization. Initially, most of these workflows have been created to manage the lifecycle of our support tasks.

The repository contains two types of workflows:
* Reusable workflows under `.github/workflows`
* Synced workflows under `workflows`

## Reusable workflows

These workflows are, and must be, under `.github/workflows` folder due to GitHub restrictions. These files were extracted from other repositories and they were created for especific events, for that reason we tried to follow this convention `<webhook>-<activity-type>` ([About events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#about-events-that-trigger-workflows)) to name them. The main goal of these worklfows is manage the [Bitnami Project support board](https://github.com/orgs/bitnami/projects/4)

* [`comment-created.yml`](.github/workflows/comment-created.yml): Moves cards based on issue/pr comments. Also it adds the label `review-required` if the comment was added on automated PR by bitnami-bot.
* [`item-closed.yml`](.github/workflows/item-closed.yml): Sends cards to the Solved column and adss the `solved` label.
* [`item-labeled.yml`](.github/workflows/item-labeled.yml): Moves cards acording to its labels. Also it reasigns tasks if it is needed, for instance, when we are labeling with `in-progress`.
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
* REPO_ASSIGNMENT. Each repository managed by these workflows could have its own assigments, for instance, charts and containers have their own teams to manage the support tasks. It contains triage and support assignemnts for each repository and a default one if the repository doesn't have any specific assignee.
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