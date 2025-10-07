pipeline {
    agent any

    parameters {
        string(name: 'ORG_ALIAS', defaultValue: 'dev', description: 'Target Org alias (e.g., dev, sit, uat, prod)')
        text(name: 'UPDATE_MAP', defaultValue: 'canUsersGrantLoginAccess=false\nenableAdminLoginAsAnyUser=true', description: 'XML updates in key=value format (one per line)')
    }

    stages {

        stage('Checkout Source') {
            steps {
                echo "📦 Checking out source code..."
                checkout scm
            }
        }

        stage('Update XML Files') {
            steps {
                script {
                    echo "🛠 Updating XML files under force-app\\main\\default\\settings..."
                    def xmlDir = "force-app\\main\\default\\settings"

                    // Parse key=value pairs into a map
                    def updateMap = [:]
                    params.UPDATE_MAP.split("\n").each { line ->
                        def parts = line.trim().split("=")
                        if (parts.size() == 2) {
                            updateMap[parts[0].trim()] = parts[1].trim()
                        }
                    }

                    // Get list of XML files using PowerShell
                    def filesOutput = bat(script: "powershell -Command \"Get-ChildItem -Path '${xmlDir}' -Filter *.xml | ForEach-Object { $_.FullName }\"", returnStdout: true).trim()
                    def files = filesOutput.split("\r?\n")

                    files.each { filePath ->
                        def content = readFile(file: filePath)
                        updateMap.each { key, value ->
                            def oldPattern = "<${key}>.*?</${key}>"
                            def newPattern = "<${key}>${value}</${key}>"
                            if (content =~ oldPattern) {
                                content = content.replaceAll(oldPattern, newPattern)
                                echo "✅ Updated '${key}' to '${value}' in ${filePath}"
                            } else {
                                echo "⚠️ Tag '${key}' not found in ${filePath}"
                            }
                        }
                        writeFile(file: filePath, text: content)
                    }
                }
            }
        }

        stage('Validate Updates') {
            steps {
                script {
                    echo "🔍 Validating XML updates..."
                    def xmlDir = "force-app\\main\\default\\settings"
                    def filesOutput = bat(script: "powershell -Command \"Get-ChildItem -Path '${xmlDir}' -Filter *.xml | ForEach-Object { $_.FullName }\"", returnStdout: true).trim()
                    def files = filesOutput.split("\r?\n")
                    def failed = false

                    files.each { filePath ->
                        def content = readFile(file: filePath)
                        params.UPDATE_MAP.split("\n").each { line ->
                            def (key, value) = line.trim().tokenize("=")
                            if (!content.contains("<${key}>${value}</${key}>")) {
                                echo "❌ Validation failed for ${key} in ${filePath}"
                                failed = true
                            }
                        }
                    }

                    if (failed) {
                        error("XML validation failed — some values not updated correctly.")
                    } else {
                        echo "✅ All XML values validated successfully."
                    }
                }
            }
        }

        stage('Commit Changes to Git') {
            steps {
                script {
                    echo "💾 Committing updated XML files..."
                    bat '''
                        git config user.email "jenkins@local"
                        git config user.name "Jenkins"
                        git add force-app\\main\\default\\settings\\*.xml
                        git commit -m "Automated XML update via Jenkins pipeline" || echo "⚠️ No changes to commit"
                        git push origin HEAD:main || echo "⚠️ Git push skipped (permissions or no changes)"
                    '''
                }
            }
        }

        stage('Deploy to Salesforce Org') {
            steps {
                script {
                    echo "🚀 Deploying updated metadata to org: ${params.ORG_ALIAS}"
                    bat """
                        sf project deploy start --source-dir force-app --target-org ${params.ORG_ALIAS} --ignore-warnings --verbose
                    """
                }
            }
        }
    }

    post {
        failure {
            echo "❌ Deployment failed. Review logs and rollback if needed."
        }
        success {
            echo "🎉 Deployment completed successfully for ${params.ORG_ALIAS}!"
        }
    }
}
