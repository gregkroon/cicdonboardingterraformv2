terraform {
  required_providers {
    harness = {
      source = "harness/harness"
    }
  }
}

provider "harness" {
  platform_api_key = var.HARNESS_API_KEY
  account_id = var.HARNESS_ACCOUNT_ID
  endpoint = "https://app.harness.io/gateway"
}

resource "harness_platform_project" "project" {
  name = var.HARNESS_PROJECT_ID
  identifier  = var.HARNESS_PROJECT_ID
  org_id      = var.HARNESS_ORG_ID
  description = "Example project description"
}



resource "harness_platform_secret_text" "githubsecret" {

  depends_on = [harness_platform_project.project]
 
  org_id      = var.HARNESS_ORG_ID
  project_id  = var.HARNESS_PROJECT_ID
  name =  "HARNESS_GITHUB_SECRET"
  identifier = "HARNESS_GITHUB_SECRET"
  secret_manager_identifier = "harnessSecretManager"
  value = var.HARNESS_GITHUB_SECRET_VALUE
  value_type = "Inline"
  
}

resource "harness_platform_secret_text" "awssecret" {

  depends_on = [harness_platform_project.project]
 
  org_id      = var.HARNESS_ORG_ID
  project_id  = var.HARNESS_PROJECT_ID
  name = "AWS_SECRET_KEY"
  identifier = "AWS_SECRET_KEY"
  secret_manager_identifier = "harnessSecretManager"
  value = var.AWS_SECRET_KEY
  value_type = "Inline"

  
}


resource "harness_platform_connector_aws" "aws_connector" {

depends_on = [harness_platform_secret_text.awssecret]

  org_id      = var.HARNESS_ORG_ID
  project_id  = var.HARNESS_PROJECT_ID
  identifier = "HARNESS_AWS_CONNECTOR"
  name = "HARNESS_AWS_CONNECTOR"


   manual {
    access_key = var.AWS_ACCESS_KEY
    secret_key_ref = "AWS_SECRET_KEY"

}
}


resource "harness_platform_connector_github" "github_connector" {

  depends_on = [harness_platform_secret_text.githubsecret]

  org_id      = var.HARNESS_ORG_ID
  project_id  = var.HARNESS_PROJECT_ID
  identifier = "HARNESS_GITHUB_CONNECTOR_ID"
  connection_type = "Account"
  name = "HARNESS_GITHUB_CONNECTOR_ID"
  url =  var.HARNESS_GITHUB_URL
  execute_on_delegate = false

  credentials {
    http {
      username = var.GITHUB_USER
      token_ref    = "HARNESS_GITHUB_SECRET"
    }
  }
  api_authentication {
    token_ref = "HARNESS_GITHUB_SECRET"
  }
}


resource "harness_platform_service" "example" {
  depends_on = [harness_platform_project.project]
  identifier  = var.HARNESS_PROJECT_ID
  name        = var.HARNESS_PROJECT_ID
  description = "test"
  org_id      = var.HARNESS_ORG_ID
  project_id  = var.HARNESS_PROJECT_ID

  ## SERVICE V2 UPDATE
  ## We now take in a YAML that can define the service definition for a given Service
  ## It isn't mandatory for Service creation 
  ## It is mandatory for Service use in a pipeline

yaml = <<-EOT
service:
  name: ${var.HARNESS_PROJECT_ID}
  identifier: ${var.HARNESS_PROJECT_ID}
  orgIdentifier: ${var.HARNESS_ORG_ID}
  projectIdentifier: ${var.HARNESS_PROJECT_ID}
  serviceDefinition:
    type: Kubernetes
    spec:
      manifests:
        - manifest:
            identifier: ${var.HARNESS_PROJECT_ID}
            type: K8sManifest
            spec:
              store:
                type: Github
                spec:
                  connectorRef: HARNESS_GITHUB_CONNECTOR_ID
                  gitFetchType: Branch
                  paths:
                    - deployment.yaml
                  repoName: ${var.HARNESS_PROJECT_ID}
                  branch: main
              valuesPaths:
                - values.yaml
              skipResourceVersioning: false
              enableDeclarativeRollback: false
      artifacts:
        primary:
          spec:
            connectorRef: account.awskey
            imagePath: kotlin
            tag: <+pipeline.stages.Build.spec.execution.steps.BuildAndPushDockerRegistry.artifact_BuildAndPushDockerRegistry.stepArtifacts.publishedImageArtifacts[0].tag>
            digest: ""
            region: ap-southeast-2
          type: Ecr
      type: Kubernetes
EOT
}

resource "harness_platform_environment" "example" {
  depends_on   = [harness_platform_project.project]
  identifier   = "Development"
  name         = "Development"
  org_id       = var.HARNESS_ORG_ID
  project_id   = var.HARNESS_PROJECT_ID
  type         = "PreProduction"
}

resource "harness_platform_infrastructure" "example" {
  depends_on   = [harness_platform_environment.example]
  identifier      = "Developmentcluster"
  name            = "Developmentcluster"
  org_id          =  var.HARNESS_ORG_ID
  project_id      = var.HARNESS_PROJECT_ID
  env_id          = "Development"
  type            = "KubernetesDirect"
  deployment_type = "Kubernetes"
  yaml            = <<-EOT
  infrastructureDefinition:
    name: Developmentcluster
    identifier: Developmentcluster
    orgIdentifier: default
    projectIdentifier: ${var.HARNESS_PROJECT_ID}
    environmentRef: Development
    deploymentType: Kubernetes
    type: KubernetesDirect
    spec:
      connectorRef: account.developmentcluster
      namespace: default
      releaseName: release-<+INFRA_KEY_SHORT_ID>
    allowSimultaneousDeployments: false
  EOT
}

resource "harness_platform_pipeline" "example" {

  depends_on = [harness_platform_infrastructure.example]
  
  identifier = var.HARNESS_PROJECT_ID
  org_id     = var.HARNESS_ORG_ID
  project_id = var.HARNESS_PROJECT_ID
  name       = var.HARNESS_PROJECT_ID
  git_details {
    branch_name    = "main"
    commit_message = "commitMessage"
    #file_path      = ${var.project_id
    connector_ref  = "HARNESS_GITHUB_CONNECTOR_ID"
    store_type     = "INLINE"
    repo_name      = var.HARNESS_PROJECT_ID
  }
yaml = <<-EOF
pipeline:
  name: ${var.HARNESS_PROJECT_ID}
  identifier: ${var.HARNESS_PROJECT_ID}
  allowStageExecutions: false
  projectIdentifier: ${var.HARNESS_PROJECT_ID}
  orgIdentifier: ${var.HARNESS_ORG_ID}
  tags: {}
  stages:
    - stage:
        name: Build
        identifier: Build
        description: ""
        type: CI
        spec:
          cloneCodebase: true
          caching:
            enabled: true
          platform:
            os: Linux
            arch: Amd64
          runtime:
            type: Cloud
            spec: {}
          execution:
            steps:
              - step:
                  type: Run
                  name: Test
                  identifier: Test
                  spec:
                    connectorRef: account.harnessImage
                    image: gradle:jdk17
                    shell: Sh
                    command: ./gradlew test
                  when:
                    stageStatus: Success
              - step:
                  type: BuildAndPushECR
                  name: BuildAndPushECR
                  identifier: BuildAndPushECR
                  spec:
                    connectorRef: account.awskey
                    region: ap-southeast-2
                    account: "759984737373"
                    imageName: 759984737373.dkr.ecr.ap-southeast-2.amazonaws.com/kotlin
                    tags:
                      - <+pipeline.sequenceId>
                    caching: true
    - stage:
        name: Development
        identifier: dep
        description: ""
        type: Deployment
        spec:
          serviceConfig:
            serviceRef: ${var.HARNESS_PROJECT_ID}
            serviceDefinition:
              type: Kubernetes
              spec:
                manifests:
                  - manifest:
                      identifier: petclinic
                      type: K8sManifest
                      spec:
                        store:
                          type: Github
                          spec:
                            connectorRef: HARNESS_GITHUB_CONNECTOR_ID
                            gitFetchType: Branch
                            paths:
                              - deployment.yaml
                            repoName: ${var.HARNESS_PROJECT_ID}
                            branch: main
                        valuesPaths:
                          - values.yaml
                        skipResourceVersioning: false
                        enableDeclarativeRollback: false
                artifacts:
                  primary:
                    spec:
                      connectorRef: HARNESS_AWS_CONNECTOR
                      imagePath: kotlin
                      tag: <+pipeline.stages.Build.spec.execution.steps.BuildAndPushECR.artifact_BuildAndPushECR.stepArtifacts.publishedImageArtifacts[0].tag>
                      digest: ""
                      region: ap-southeast-2
                    type: Ecr
          infrastructure:
            environmentRef: Development
            infrastructureDefinition:
              type: KubernetesDirect
              spec:
                connectorRef: account.developmentcluster
                namespace: default
                releaseName: release-<+INFRA_KEY>
            allowSimultaneousDeployments: false
          execution:
            steps:
              - stepGroup:
                  name: Canary Deployment
                  identifier: canaryDepoyment
                  steps:
                    - step:
                        name: Canary Deployment
                        identifier: canaryDeployment
                        type: K8sCanaryDeploy
                        timeout: 10m
                        spec:
                          instanceSelection:
                            type: Count
                            spec:
                              count: 1
                          skipDryRun: false
                    - step:
                        name: Canary Delete
                        identifier: canaryDelete
                        type: K8sCanaryDelete
                        timeout: 10m
                        spec: {}
                  rollbackSteps:
                    - step:
                        name: Canary Delete
                        identifier: rollbackCanaryDelete
                        type: K8sCanaryDelete
                        timeout: 10m
                        spec: {}
              - stepGroup:
                  name: Primary Deployment
                  identifier: primaryDepoyment
                  steps:
                    - step:
                        name: Rolling Deployment
                        identifier: rollingDeployment
                        type: K8sRollingDeploy
                        timeout: 10m
                        spec:
                          skipDryRun: false
                  rollbackSteps:
                    - step:
                        name: Rolling Rollback
                        identifier: rollingRollback
                        type: K8sRollingRollback
                        timeout: 10m
                        spec: {}
            rollbackSteps: []
          rollbackSteps: []
        tags: {}
        failureStrategies:
          - onFailure:
              errors:
                - AllErrors
              action:
                type: StageRollback
  properties:
    ci:
      codebase:
        connectorRef: HARNESS_GITHUB_CONNECTOR_ID
        repoName: spring-petclinic-kotlin
        build:
          type: branch
          spec:
            branch: main
        sparseCheckout: []
EOF
}


resource "harness_platform_triggers" "example" {

depends_on = [harness_platform_pipeline.example]

  identifier = var.HARNESS_PROJECT_ID
  org_id     = var.HARNESS_ORG_ID
  project_id = var.HARNESS_PROJECT_ID
  name       = var.HARNESS_PROJECT_ID
  target_id  = var.HARNESS_PROJECT_ID
  yaml       = <<-EOT
trigger:
  name: PR trigger
  identifier: PR_trigger
  enabled: true
  encryptedWebhookSecretIdentifier: ""
  description: ""
  tags: {}
  orgIdentifier: default
  stagesToExecute: []
  projectIdentifier: ${var.HARNESS_PROJECT_ID}
  pipelineIdentifier: ${var.HARNESS_PROJECT_ID}
  source:
    type: Webhook
    spec:
      type: Github
      spec:
        type: PullRequest
        spec:
          connectorRef: HARNESS_GITHUB_CONNECTOR_ID
          autoAbortPreviousExecutions: false
          payloadConditions:
            - key: targetBranch
              operator: Equals
              value: main
          headerConditions: []
          repoName: ${var.HARNESS_PROJECT_ID}
          actions:
            - Close
  inputYaml: |
    pipeline:
      identifier: ${var.HARNESS_PROJECT_ID}
      stages:
        - stage:
            identifier: Build
            type: CI
            spec:
              execution:
                steps:
                  - step:
                      identifier: BuildAndPushECR
                      type: BuildAndPushECR
                      spec:
                        connectorRef: HARNESS_AWS_CONNECTOR
        - stage:
            identifier: dep
            type: Deployment
            spec:
              serviceConfig:
                serviceRef: ${var.HARNESS_PROJECT_ID}
                serviceDefinition:
                  type: Kubernetes
                  spec:
                    manifests:
                      - manifest:
                          identifier: petclinic
                          type: K8sManifest
                          spec:
                            store:
                              type: Github
                              spec:
                                connectorRef: HARNESS_GITHUB_CONNECTOR_ID
                    artifacts:
                      primary:
                        type: Ecr
                        spec:
                          connectorRef: HARNESS_AWS_CONNECTOR
              infrastructure:
                environmentRef: Development
                infrastructureDefinition:
                  type: KubernetesDirect
                  spec:
                    connectorRef: account.developmentcluster
      properties:
        ci:
          codebase:
            connectorRef: HARNESS_GITHUB_CONNECTOR_ID
            repoName: ${var.HARNESS_PROJECT_ID}
            build:
              type: branch
              spec:
                branch: <+trigger.branch>
  EOT
  }   
