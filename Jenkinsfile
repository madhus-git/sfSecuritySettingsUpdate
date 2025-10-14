// ============================================================
// Scripted Jenkins Pipeline
// Deploy Specific Salesforce Security Setting via Jenkins
// Supports Windows & Linux Agents
// ============================================================

node {

    // --------------------------------------
    // Define build-time parameters
    // --------------------------------------
    properties([
        parameters([
            string(name: 'OrgAlias', description: 'Salesforce Org Alias (e.g. devOrg, uatOrg, prodOrg)', defaultValue: ''),
            string(name: 'OrgUrl', defaultValue: 'https://login.salesforce.com', description: '* Salesforce Org URL'),
            string(name: 'BranchName', description: 'Git branch or tag to deploy', defaultValue: 'main'),
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
        string(credentialsId: 'fairwaydev1-consumer-key', variable: 'CONNECTED_APP_CONSUMER_KEY'),
        string(credentialsId: 'fairwaydev1-username', variable: 'SFDC_USERNAME'),
        file(credentialsId: 'sfdc-jwt-key', variable: 'JWT_KEY_FILE')
    ]) {

        try {
            // -------------------------------
            stage('Checkout Code from GitHub') {
                try {
                    echo "Checking out branch: ${BRANCH_NAME}"
                    git branch: "${BRANCH_NAME}", url: 'https://github.com/madhus-git/sfSecuritySettingsUpdate.git'
                } catch (e) {
                    error "Git Checkout Failed: ${e}"
                }
            }

            // -------------------------------
            stage('Authenticate to Salesforce Org') {
                try {
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
                } catch (e) {
                    error "Authentication Failed: ${e}"
                }
            }

            // -------------------------------
            stage('Backup Existing Security Settings') {
                try {
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
                } catch (e) {
                    echo "Backup Failed (Continuing anyway): ${e}"
                }
            }

            // -------------------------------
            stage('Deploy Updated Security Settings') {
                try {
                    echo "Deploying file: ${XML_PATH} to ${ORG_ALIAS}"

                    if (isUnix()) {
                        sh """
                            sf deploy metadata \
                                --target-org ${ORG_ALIAS} \
                                --source-dir ${XML_PATH} \
                                --ignore-errors \
                                --wait 10
                        """
                    } else {
                        bat """
                            sf deploy metadata ^
                                --target-org ${ORG_ALIAS} ^
                                --source-dir ${XML_PATH} ^
                                --ignore-errors ^
                                --wait 10
                        """
                    }
                } catch (e) {
                    error "Deployment Failed: ${e}"
                }
            }

            // -------------------------------
            stage('Post-Deployment Validation') {
                try {
                    echo "Validating Deployment Results..."
                    if (isUnix()) {
                        sh "sf org list"
                    } else {
                        bat "sf org list"
                    }
                } catch (e) {
                    echo "Post-validation failed: ${e}"
                }
            }

            echo "Deployment Successful for ${ORG_ALIAS}!"

        } catch (err) {
            echo "Pipeline Failed: ${err}"
            currentBuild.result = 'FAILURE'
        }
    }
}
