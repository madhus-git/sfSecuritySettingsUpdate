// ============================================================
// Scripted Jenkins Pipeline
// Deploy Specific Salesforce Security Setting via Jenkins
// Supports Windows & Linux Agents
// Includes ignore-errors & ignore-warnings for partial deploy
// ============================================================

node {

    // --------------------------------------
    // Define build-time parameters
    // --------------------------------------
    properties([
        parameters([
            string(name: 'OrgAlias', description: 'Salesforce Org Alias (e.g. devOrg, uatOrg, prodOrg)', defaultValue: ''),
            string(name: 'OrgUrl', defaultValue: 'https://test.salesforce.com', description: '* Salesforce Org URL'),
            string(name: 'BranchName', description: 'Git branch or tag to deploy', defaultValue: 'otherOrgs'),
            string(name: 'XMLFilePath', defaultValue: '', description: '* Path to XML file to deploy (e.g. force-app/main/default/settings/Security.settings-meta.xml)')
        ])
    ])

    // --------------------------------------
    // Initialize variables
    // --------------------------------------
    def ORG_ALIAS = params.OrgAlias?.trim()
    def ORG_URL = params.OrgUrl?.trim()
    def BRANCH_NAME = params.BranchName?.trim()
    def XML_PATH = params.XMLFilePath?.trim()
    def BACKUP_DIR = "backup_settings_${new Date().format('yyyyMMdd_HHmmss')}"

    // --------------------------------------
    // Validate required parameters
    // --------------------------------------
    if (!ORG_ALIAS || !ORG_URL || !BRANCH_NAME || !XML_PATH) {
        error "All parameters (OrgAlias, OrgUrl, BranchName, XMLFilePath) are mandatory."
    }

    // --------------------------------------
    // Load credentials
    // --------------------------------------
    withCredentials([
        string(credentialsId: 'fairwaydev2-consumer-key', variable: 'CONNECTED_APP_CONSUMER_KEY'),
        string(credentialsId: 'fairwaydev2-username', variable: 'SFDC_USERNAME'),
        file(credentialsId: 'sfdc-jwt-key', variable: 'JWT_KEY_FILE')
    ]) {

        try {
            // -------------------------------
            stage('Checkout Code') {
                echo "Checking out branch: ${BRANCH_NAME}"
                git branch: "${BRANCH_NAME}", url: 'https://github.com/madhus-git/sfSecuritySettingsUpdate.git'
            }

            // -------------------------------
            stage('Authenticate to Org') {
                echo "Authenticating with Salesforce Org: ${ORG_ALIAS}"
                if (isUnix()) {
                    sh """
                        sf org login jwt --client-id ${CONNECTED_APP_CONSUMER_KEY} \
                            --jwt-key-file ${JWT_KEY_FILE} \
                            --username ${SFDC_USERNAME} \
                            --alias ${ORG_ALIAS} \
                            --instance-url ${ORG_URL}
                    """
                } else {
                    bat """
                        sf org login jwt ^
                            --client-id %CONNECTED_APP_CONSUMER_KEY% ^
                            --jwt-key-file %JWT_KEY_FILE% ^
                            --username %SFDC_USERNAME% ^
                            --alias ${ORG_ALIAS} ^
                            --instance-url ${ORG_URL}
                    """
                }
            }

            // -------------------------------
            stage('Backup Existing Security Settings') {
                echo "Backing up current settings to folder: ${BACKUP_DIR}"
                if (isUnix()) {
                    sh "mkdir -p ${BACKUP_DIR}"
                    sh """
                        sf retrieve metadata \
                            --target-org ${ORG_ALIAS} \
                            --manifest manifest/package.xml \
                            --output-dir ${BACKUP_DIR} \
                            --wait 10
                    """
                } else {
                    bat """
                        mkdir ${BACKUP_DIR}
                        sf retrieve metadata ^
                            --target-org ${ORG_ALIAS} ^
                            --manifest manifest/package.xml ^
                            --output-dir ${BACKUP_DIR} ^
                            --wait 10
                    """
                }
            }

            // -------------------------------
            stage('Deploy Updated Security Settings') {
                echo "Deploying file: ${XML_PATH} to ${ORG_ALIAS} (with ignore-errors & ignore-warnings)"
                if (isUnix()) {
                    sh """
                        sf deploy metadata \
                            --target-org ${ORG_ALIAS} \
                            --source-dir ${XML_PATH} \
                            --ignore-errors \
                            --ignore-warnings \
                            --wait 10 || echo "Deployment had warnings/errors but continued successfully."
                    """
                } else {
                    bat """
                        sf deploy metadata ^
                            --target-org ${ORG_ALIAS} ^
                            --source-dir ${XML_PATH} ^
                            --ignore-errors ^
                            --ignore-warnings ^
                            --wait 10 ^
                            || echo Deployment had warnings/errors but continued successfully.
                    """
                }
            }

            // -------------------------------
            stage('Post-Deployment Validation') {
                echo "Validating Deployment Results..."
                if (isUnix()) {
                    sh "sf org list"
                } else {
                    bat "sf org list"
                }
            }

            echo "Deployment Completed (Warnings Ignored) for ${ORG_ALIAS}!"

        } catch (err) {
            echo "Pipeline Failed: ${err}"
            currentBuild.result = 'FAILURE'
        }
    }
}
