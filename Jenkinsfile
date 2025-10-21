// ============================================================
// Scripted Jenkins Pipeline
// Deploy Salesforce Settings with Skip-on-Failure Support
// ============================================================

node {
    properties([
        parameters([
            string(name: 'OrgAlias', defaultValue: '', description: 'Salesforce Org Alias'),
            string(name: 'OrgUrl', defaultValue: 'https://test.salesforce.com', description: 'Salesforce Org URL'),
            string(name: 'BranchName', defaultValue: 'deploySecurityValues', description: 'Branch name'),
            string(name: 'XMLFilePath', defaultValue: '', description: 'Path to XML file to deploy'),
            string(name: 'ApiVersion', defaultValue: '64.0', description: 'Salesforce API version')
        ])
    ])

    def ORG_ALIAS = params.OrgAlias.trim()
    def ORG_URL = params.OrgUrl.trim()
    def BRANCH = params.BranchName.trim()
    def XML_FILE = params.XMLFilePath.trim()
    def API_VER = params.ApiVersion.trim()
    def LOG_FILE = "deploy_log.txt"

    if (!ORG_ALIAS || !ORG_URL || !XML_FILE) {
        error "Missing required parameters (OrgAlias, OrgUrl, XMLFilePath)"
    }

    withCredentials([
        string(credentialsId: 'fairwaydev2-consumer-key', variable: 'CONNECTED_APP_CONSUMER_KEY'),
        string(credentialsId: 'fairwaydev2-username', variable: 'SFDC_USERNAME'),
        file(credentialsId: 'sfdc-jwt-key', variable: 'JWT_KEY_FILE')
    ]) {
        try {
            stage('Checkout') {
                echo "Checking out branch ${BRANCH}"
                git branch: "${BRANCH}", url: 'https://github.com/madhus-git/sfSecuritySettingsUpdate.git'
            }

            stage('Authenticate') {
                echo "Authenticating Salesforce org: ${ORG_ALIAS}"
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

            stage('Deploy Metadata') {
                echo "Deploying ${XML_FILE} (API v${API_VER})..."
                def deployCmd = isUnix() ?
                    "sf deploy metadata --target-org ${ORG_ALIAS} --source-dir ${XML_FILE} --ignore-warnings --wait 10 --json > ${LOG_FILE} || true" :
                    "sf deploy metadata --target-org ${ORG_ALIAS} --source-dir ${XML_FILE} --ignore-warnings --wait 10 --json > ${LOG_FILE} || exit /b 0"

                if (isUnix()) sh deployCmd else bat deployCmd
            }

            stage('Check for Failures') {
    script {
        echo "Checking for failed tags in deployment..."

        def logContent = readFile(LOG_FILE)
        def failedTags = []
        def summaryFile = "deployment_summary.txt"
        def timestamp = new Date().format("yyyy-MM-dd HH:mm:ss")

        // Extract failed component names directly (no matcher objects persist)
        def pattern = /"componentFailures"[\s\S]*?"fullName"\s*:\s*"([^"]+)"/
        def lines = (logContent =~ pattern).collect { it[1] }

        if (lines && lines.size() > 0) {
            failedTags = lines.unique()
            echo "Some components failed during deployment:"
            failedTags.each { echo "   • ${it}" }

            // Clean up XML file by removing failed tags
            def xmlText = readFile(XML_FILE)
            failedTags.each { tagName ->
                def tagRegex = "(?s)<${tagName}>.*?</${tagName}>"
                xmlText = xmlText.replaceAll(tagRegex, "")
                echo "Removed failed tag: ${tagName}"
            }

            // Print cleaned XML in Jenkins console
            echo "==============================================="
            echo "Cleaned XML after removing failed tags:"
            echo "==============================================="
            echo "${xmlText}"
            echo "==============================================="

            // Write updated XML file
            writeFile file: XML_FILE, text: xmlText
            echo "Updated XML written to: ${XML_FILE}"

            // Generate deployment summary report
            def summaryText = """\
==============================
Salesforce Deployment Summary
==============================
Timestamp     : ${timestamp}
Org Alias     : ${ORG_ALIAS}
Org URL       : ${ORG_URL}
XML File      : ${XML_FILE}
API Version   : ${API_VER}

Failed Tags:
${failedTags.collect { "   • ${it}" }.join('\n')}

Cleaned XML Content:
----------------------------------------------
${xmlText}
----------------------------------------------

Status: UNSTABLE (Skipped failed tags; manual review required)
"""
            writeFile file: summaryFile, text: summaryText
            echo "Deployment summary saved to ${summaryFile}"

            // Redeploy remaining components
            echo "Redeploying remaining content..."
            def redeployCmd = isUnix() ?
                "sf deploy metadata --target-org ${ORG_ALIAS} --source-dir ${XML_FILE} --ignore-errors --ignore-warnings --api-version ${API_VER} --wait 10 || true" :
                "sf deploy metadata --target-org ${ORG_ALIAS} --source-dir ${XML_FILE} --ignore-errors --ignore-warnings --api-version ${API_VER} --wait 10 || exit /b 0"

            if (isUnix()) {
                sh redeployCmd
            } else {
                bat redeployCmd
            }

            // Archive summary for Jenkins UI
            archiveArtifacts artifacts: summaryFile, fingerprint: true

            currentBuild.result = 'UNSTABLE'
            echo "Deployment completed (skipped failed tags). Manual review recommended."

        } else {
            echo "All tags deployed successfully!"

            def xmlText = readFile(XML_FILE)
            def summaryText = """\
==============================
Salesforce Deployment Summary
==============================
Timestamp     : ${timestamp}
Org Alias     : ${ORG_ALIAS}
Org URL       : ${ORG_URL}
XML File      : ${XML_FILE}
API Version   : ${API_VER}

All tags deployed successfully!

Cleaned XML Content:
----------------------------------------------
${xmlText}
----------------------------------------------

Status: SUCCESS
"""
            writeFile file: summaryFile, text: summaryText
            archiveArtifacts artifacts: summaryFile, fingerprint: true
            echo "Deployment summary saved to ${summaryFile}"
        }
    }
}


        } catch (e) {
            echo "Pipeline error: ${e}"
            currentBuild.result = 'FAILURE'
        }
    }
}
