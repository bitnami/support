# support
Support dashboards and common workflows

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
      org: bitnami
      legacy_project_board_name: Support
      new_project_number: 4
      repo: ${{ github.event.repository.name }}
    secrets:
      # This token should have access to both projects and at least read:project permissions
      token: GITHUB_TOKEN
```

### About the process

The hard work is done by this [piece of code](.github/scripts/migrate.sh) but in general lines the proccess is easy:

1. Retrieve information about projects.
2. Loop over each project (classic) column.
3. Get the cards from each column.
4. Create new cards in the new Project.
5. Move each new card to the right column.

NOTES:
* The process will migrate all cards in one excution.
* If you face any error you can trigger the workflow again, no duplications should occur in the target Project.
* If you have a significant number of cards you could reach github thresholds, in that case you should remove/archive previously migrated cards in the source Project (classic) to reduce the number of requests.
