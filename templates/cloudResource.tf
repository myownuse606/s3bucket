name: Create cloud resource
on:
  workflow_dispatch:
    inputs:
      name:
        type: string
      visibility:
        type: string
      port_payload:
        required: true
        description: Port's payload, including details for who triggered the action and general context
        type: string
jobs:
  createResource:
    runs-on: ubuntu-latest
    steps:
      # Checkout the workflow's repository
      - uses: actions/checkout@v4
      # Checkout the service's repository
      - uses: actions/checkout@v4
        with:
          repository: "${{ github.repository_owner }}/${{fromJson(inputs.port_payload).context.entity}}"
          path: ./targetRepo
          token: ${{ secrets.ORG_ADMIN_TOKEN }}
      - name: Copy template file
        run: |
          mkdir -p ./targetRepo/resources
          cp templates/cloudResource.tf ./targetRepo/resources/${{ inputs.name }}.tf
      - name: Update new file data
        run: |
          sed -i 's/{{ bucket_name }}/${{ inputs.name }}/' ./targetRepo/resources/${{ inputs.name }}.tf
          sed -i 's/{{ bucket_acl }}/${{ inputs.visibility }}/' ./targetRepo/resources/${{ inputs.name }}.tf
      - name: Open a pull request
        uses: peter-evans/create-pull-request@v5
        with:
          token: ${{ secrets.ORG_ADMIN_TOKEN }}
          path: ./targetRepo
          commit-message: Create new resource - ${{ inputs.name }}
          committer: GitHub <noreply@github.com>
          author: ${{ github.actor }} <${{ github.actor }}@users.noreply.github.com>
          signoff: false
          branch: new-resource-${{ inputs.name }}
          delete-branch: true
          title: Create new resource - ${{ inputs.name }}
          body: |
            Create new ${{ inputs.visibility }} resource - ${{ inputs.name }}
          draft: false
  create-entity-in-port-and-update-run:
    runs-on: ubuntu-latest
    needs: createResource
    steps:
      - name: UPSERT Entity
        uses: port-labs/port-github-action@v1
        with:
          identifier: ${{fromJson(inputs.port_payload).context.entity}}
          blueprint: service
          properties: |-
            {
              "resource_definitions": "${{ github.server_url }}/${{ github.repository_owner }}/${{fromJson(inputs.port_payload).context.entity}}/blob/main/resources/"
            }
          clientId: ${{ secrets.PORT_CLIENT_ID }}
          clientSecret: ${{ secrets.PORT_CLIENT_SECRET }}
          operation: UPSERT
          runId: ${{fromJson(inputs.port_payload).context.runId}}
      - name: Create a log message
        uses: port-labs/port-github-action@v1
        with:
          clientId: ${{ secrets.PORT_CLIENT_ID }}
          clientSecret: ${{ secrets.PORT_CLIENT_SECRET }}
          operation: PATCH_RUN
          runId: ${{fromJson(inputs.port_payload).context.runId}}
          logMessage: Pull request created successfully for "${{ inputs.name }}" 🚀
