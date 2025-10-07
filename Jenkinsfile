node {
    // -------------------------------
    // 0️⃣ Checkout repository
    // -------------------------------
    stage('Checkout') {
        echo "[STEP] Checking out repository..."
        checkout scm
    }

    // -------------------------------
    // 1️⃣ Parameters (passed at build)
    // -------------------------------
    def orgAlias = params.ORG_ALIAS
    def xmlFilesInput = params.XML_FILES        // Comma-separated XML files
    def tagsInput = params.TAGS_MAP             // Format: filePath:tag1=value1,tag2=value2 per line

    if (!orgAlias || !xmlFilesInput || !tagsInput) {
        error "Please provide ORG_ALIAS, XML_FILES, and TAGS_MAP as build parameters"
    }

    def logDir = "deployment_logs"
    def backupDir = "backups"
    def packageXml = "./manifest/package.xml"
    def waitTime = 30
    def testLevel = "RunLocalTests"
    def timestamp = new Date().format('yyyyMMdd_HHmmss')
    def backupFiles = [:]  // Track backups for rollback

    // -------------------------------
    // Helper Functions
    // -------------------------------
    def parseTags = { tagsStr ->
        def map = [:]
        tagsStr.split(",").each { kv ->
            def pair = kv.trim().split("=")
            if(pair.size() == 2) { map[pair[0]] = pair[1] }
        }
        return map
    }

    def copyFile = { src, dest ->
        if (isUnix()) {
            sh "cp '${src}' '${dest}'"
        } else {
            src = src.replace('/', '\\')
            dest = dest.replace('/', '\\')
            bat "copy /Y \"${src}\" \"${dest}\""
        }
    }

    try {
        // -------------------------------
        // 2️⃣ Prepare directories
        // -------------------------------
        stage('Prepare') {
            echo "[STEP] Creating log and backup directories..."
            if (isUnix()) {
                sh "mkdir -p ${logDir} ${backupDir}"
            } else {
                bat """
                if not exist "${logDir}" mkdir "${logDir}"
                if not exist "${backupDir}" mkdir "${backupDir}"
                """
            }
        }

        // -------------------------------
        // 3️⃣ Validate XML files exist
        // -------------------------------
        stage('Validate XML Paths') {
            echo "[STEP] Validating XML file paths..."
            xmlFilesInput.split(",").each { file ->
                file = file.trim()
                if (isUnix()) {
                    sh "test -f '${file}' || (echo File not found: ${file} && exit 1)"
                } else {
                    bat "if not exist \"${file}\" (echo File not found: ${file} & exit 1)"
                }
                echo "Found XML file: ${file}"
            }
        }

        // -------------------------------
        // 4️⃣ Backup XML files
        // -------------------------------
        stage('Backup XML') {
            echo "[STEP] Backing up XML files..."
            xmlFilesInput.split(",").each { file ->
                file = file.trim()
                def backupFile = "${file}.bak_${timestamp}"
                backupFiles[file] = backupFile

                copyFile(file, backupFile)
                echo "Backup created: ${backupFile}"
            }
            env.BACKUP_FILES = groovy.json.JsonOutput.toJson(backupFiles)
        }

        // -------------------------------
        // 5️⃣ Update XML files
        // -------------------------------
        stage('Update XML') {
            echo "[STEP] Updating XML files..."
            tagsInput.split("\n").each { line ->
                if(line.trim()) {
                    def parts = line.split(":")
                    if(parts.size() != 2) { error "Invalid format in TAGS_MAP: ${line}" }
                    def xmlFile = parts[0].trim()
                    def tags = parseTags(parts[1].trim())

                    echo "Updating ${xmlFile} with tags: ${tags}"

                    def psScript = """
                        [xml]\$xml = Get-Content "${xmlFile}"
                        \$nsMgr = New-Object System.Xml.XmlNamespaceManager(\$xml.NameTable)
                        \$nsMgr.AddNamespace("ns", \$xml.DocumentElement.NamespaceURI)
                        ${tags.collect { k,v -> "\$xml.SelectSingleNode(\"//ns:${k}\", \$nsMgr).InnerText = '${v}'" }.join("\n")}
                        \$xml.Save("${xmlFile}")
                    """

                    powershell(returnStatus: true, script: psScript)
                }
            }
            echo "XML files updated successfully."
        }

        // -------------------------------
        // 6️⃣ Validate updated XML values
        // -------------------------------
        stage('Validate Changes') {
            echo "[STEP] Validating XML updates..."
            tagsInput.split("\n").each { line ->
                if(line.trim()) {
                    def parts = line.split(":")
                    def xmlFile = parts[0].trim()
                    def tags = parseTags(parts[1].trim())

                    def validationScript = """
                        [xml]\$xml = Get-Content "${xmlFile}"
                        \$nsMgr = New-Object System.Xml.XmlNamespaceManager(\$xml.NameTable)
                        \$nsMgr.AddNamespace("ns", \$xml.DocumentElement.NamespaceURI)
                        \$valid = \$true
                        ${tags.collect { k,v -> "if (\$xml.SelectSingleNode(\"//ns:${k}\", \$nsMgr).InnerText -ne '${v}') { \$valid = \$false }" }.join("\n")}
                        if (-not \$valid) { exit 1 }
                    """

                    powershell(returnStatus: true, script: validationScript)
                }
            }
            echo "Validation passed for all XML files."
        }

        // -------------------------------
        // 7️⃣ Deploy to Salesforce
        // -------------------------------
        stage('Deploy to Salesforce') {
            echo "[STEP] Deploying to org: ${orgAlias}"
            def deployLog = "${logDir}/deploy_${timestamp}.json"

            def exitCode = isUnix() ? sh(script: "sf deploy metadata --manifest ${packageXml} --target-org ${orgAlias} --test-level ${testLevel} --wait ${waitTime} --json > ${deployLog}", returnStatus: true)
                                      : bat(script: "sf deploy metadata --manifest ${packageXml} --target-org ${orgAlias} --test-level ${testLevel} --wait ${waitTime} --json > ${deployLog}", returnStatus: true)

            if(exitCode != 0) {
                error "[FAILURE] Salesforce deployment failed. Check ${deployLog}"
            }

            echo "Deployment completed. Log: ${deployLog}"
        }

        // -------------------------------
        // 8️⃣ Push updated XML files to GitHub
        // -------------------------------
        stage('Push to GitHub') {
            echo "[STEP] Pushing updated XML files to GitHub..."
            if (isUnix()) {
                sh "git config user.email 'jenkins@example.com' && git config user.name 'Jenkins CI'"
            } else {
                bat "git config user.email 'jenkins@example.com' & git config user.name 'Jenkins CI'"
            }

            xmlFilesInput.split(",").each { file ->
                file = file.trim()
                if (isUnix()) { sh "git add ${file}" } else { bat "git add \"${file}\"" }
            }

            if (isUnix()) {
                sh "git commit -m 'Updated XML files' || echo 'No changes to commit'"
                sh "git push origin HEAD"
            } else {
                bat "git commit -m \"Updated XML files\" || echo No changes to commit"
                bat "git push origin HEAD"
            }
            echo "Changes pushed to GitHub successfully."
        }

    } catch (err) {
        // -------------------------------
        // Rollback on failure
        // -------------------------------
        echo "[FAILURE] ${err}"
        if(env.BACKUP_FILES) {
            echo "[ROLLBACK] Restoring backups..."
            def backupFilesJson = env.BACKUP_FILES
            backupFiles = new groovy.json.JsonSlurper().parseText(backupFilesJson)
            backupFiles.each { orig, backup ->
                copyFile(backup, orig)
                echo "Restored ${orig} from ${backup}"
            }
        } else {
            echo "[ROLLBACK] No backups to restore"
        }
        error "Pipeline failed and rollback completed"
    }
}
