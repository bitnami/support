#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC2016

set -o errexit
set -o nounset
set -o pipefail


echo "::group::Parsing inputs"
organization="$1"
echo "organization=${organization}"
legacy_project_board_name="$1"
echo "legacy_project_board_name=${legacy_project_board_name}"
new_project_number="$3"
echo "new_project_number=${new_project_number}"
repo="$4"
echo "repo=${repo}"
echo "::endgroup::"

echo "::group::Retrieving legacy project board"
legacy_project_board="$(
  gh api --paginate "repos/${organization}/${repo}/projects" --jq "map(select(.name == \"${legacy_project_board_name}\"))" |
    jq -n '[inputs] | add | .[0]'
)"
echo "legacy_project_board=$(jq '.id' <<< "${legacy_project_board}")"
echo "::endgroup::"

echo "::group::Retrieving new project"
new_project="$(
  gh api graphql -f query='query($org: String!, $new_project_number: Int!) {
    organization(login: $org) {
      projectV2(number: $new_project_number) {
        id
        field(name: "Status"){
          ... on ProjectV2SingleSelectField {
            id
            name
            options {
              id
              name
            }
          }
        }
      }
    }
  }' -f org="${organization}" -F new_project_number="${new_project_number}" --jq '.data.organization.projectV2'
)"
echo "new_project=$(jq '.id' <<< "${new_project}")"
echo "::endgroup::"

echo "::group::Retrieving information about legacy project board and new project"
new_project_id="$(jq -r '.id' <<< "${new_project}")"
echo "new_project_id=${new_project_id}"
legacy_project_board_id="$(jq '.id' <<< "${legacy_project_board}")"
echo "legacy_project_board_id=${legacy_project_board_id}"
legacy_project_board_columns="$(gh api --paginate "projects/${legacy_project_board_id}/columns" | jq -n '[inputs] | add')"
echo "legacy_project_board_columns=$(jq 'map(.id)' <<< "${legacy_project_board_columns}")"
new_project_status_field="$(jq -r '.field' <<< "${new_project}")"
echo "new_project_status_field=$(jq '.id' <<< "{new_project_status_field}")"
new_project_status_field_id="$(jq -r '.id' <<< "${new_project_status_field}")"
echo "new_project_status_field_id=${new_project_status_field_id}"
new_project_status_field_options="$(jq -r '.options' <<< "${new_project_status_field}")"
echo "new_project_status_field_options=${new_project_status_field_options}"
echo "::endgroup::"

echo "::group::Synchronising cards"
while read -r legacy_project_board_column_id; do
  if [[ -z "$legacy_project_board_column_id" ]]; then
    continue
  fi
  echo "legacy_project_board_column_id=${legacy_project_board_column_id}"
  legacy_project_board_column_name="$(jq -r 'map(select(.id == $legacy_project_board_column_id)) | .[0].name' --argjson legacy_project_board_column_id "${legacy_project_board_column_id}" <<< "$legacy_project_board_columns")"
  echo "legacy_project_board_column_name=${legacy_project_board_column_name}"
  legacy_project_board_cards="$(gh api --paginate "projects/columns/${legacy_project_board_column_id}/cards" | jq -n '[inputs] | add')"
  echo "legacy_project_board_cards=$(jq 'map(.id)' <<< "${legacy_project_board_cards}")"
  new_project_status_field_option_id="$(jq -r 'map(select(.name == $legacy_project_board_column_name)) | .[0].id // ""' --arg legacy_project_board_column_name "${legacy_project_board_column_name}" <<< "${new_project_status_field_options}")"
  echo "new_project_status_field_option_id=${new_project_status_field_option_id}"

  while read -r legacy_project_board_card_id; do
    echo "legacy_project_board_card_id=${legacy_project_board_card_id}"
    legacy_project_board_card="$(jq -r 'map(select(.id == $legacy_project_board_card_id)) | .[0]' --argjson legacy_project_board_card_id "${legacy_project_board_card_id}" <<< "$legacy_project_board_cards")"
    echo "legacy_project_board_card=$(jq '.id' <<< "${legacy_project_board_card}")"
    legacy_project_board_card_content_url="$(jq -r '.content_url // ""' <<< "${legacy_project_board_card}")"
    echo "legacy_project_board_card_content_url=${legacy_project_board_card_content_url}"

    if [[ -z "${legacy_project_board_card_content_url}" ]]; then
      if [[ ! -z "$repo" ]]; then
        legacy_project_board_card_note="$(jq -r '.note // ""' <<< "${legacy_project_board_card}")"
        echo "legacy_project_board_card_note=${legacy_project_board_card_note}"
        legacy_project_board_card_node_id="$(gh api "repos/${organization}/${repo}/issues" -f title="${legacy_project_board_card_note:0:60}" -f body="${legacy_project_board_card_note}" --jq '.node_id')"
      else
        continue
      fi
    else
      legacy_project_board_card_node_id="$(gh api "$legacy_project_board_card_content_url" --jq '.node_id')"
    fi
    echo "legacy_project_board_card_node_id=${legacy_project_board_card_node_id}"

    new_project_item_id="$(
      gh api graphql -f query='mutation($new_project_id: ID!, $legacy_project_board_card_node_id: ID!) {
        addProjectV2ItemById(input: {projectId:  $new_project_id, contentId: $legacy_project_board_card_node_id}) {
          item {
            id
          }
        }
      }' -f new_project_id="${new_project_id}" -f legacy_project_board_card_node_id="${legacy_project_board_card_node_id}" --jq '.data.addProjectV2ItemById.item.id'
    )"
    echo "new_project_item_id=${new_project_item_id}"

    if [[ ! -z "$new_project_status_field_option_id" ]]; then
      > /dev/null gh api graphql -f query='mutation($new_project_id: ID!, $new_project_item_id: ID!, $new_project_status_field_id: ID!, $new_project_status_field_option_id: String!) {
        updateProjectV2ItemFieldValue(
          input: {
            projectId: $new_project_id
            itemId: $new_project_item_id
             fieldId: $new_project_status_field_id,
            value: { 
              singleSelectOptionId: $new_project_status_field_option_id
            }
          }
        ) {
          projectV2Item {
            id
          }
        }
      }' -f new_project_id="${new_project_id}" -f new_project_item_id="${new_project_item_id}" -f new_project_status_field_id="${new_project_status_field_id}" -f new_project_status_field_option_id="${new_project_status_field_option_id}"
    fi
  done <<< "$(jq '.[].id' <<< "$legacy_project_board_cards")"
done <<< "$(jq '.[].id' <<< "$legacy_project_board_columns")"
echo "::endgroup::"