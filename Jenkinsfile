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

    def runCommand = { cmdUnix, cmdWin ->
        if (isUnix()) {
            sh cmdUnix
        } else {
            // Convert forward slashes to backslashes for Windows
            cmdWin = cmdWin.replaceAll('/', '\\\\')
            bat cmdWin
        }
    }

    try {
        // -------------------------------
        // 2️⃣ Prepare directories
        // -------------------------------
        stage('Prepare') {
            echo "[STEP] Creating log and backup directories..."
            runCommand("mkdir -p ${logDir} ${backupDir}", """
                if not exist "${logDir}" mkdir "${logDir}"
                if not exist "${backupDir}" mkdir "${backupDir}"
            """)
        }

        // -------------------------------
        // 3️⃣ Validate XML files exist
        // -------------------------------
        stage('Validate XML Paths') {
            echo "[STEP] Validating XML file paths..."
            xmlFilesInput.split(",").each { file ->
                file = file.trim()
                runCommand(
                    "test -f ${file} || (echo File not found: ${file} && exit 1)",
                    "if not exist \"${file}\" (echo File not found: ${file} & exit 1)"
                )
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

                runCommand(
                    "cp ${file} ${backupFile}",
                    "copy /Y \"${file}\" \"${backupFile}\""
                )

                echo "Backup created: ${backupFile}"
            }
            // Save backupFiles to env for rollback
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
            runCommand(
                "sf deploy metadata --manifest ${packageXml} --target-org ${orgAlias} --test-level ${testLevel} --wait ${waitTime} --json > ${deployLog}",
                "sf deploy metadata --manifest ${packageXml} --target-org ${orgAlias} --test-level ${testLevel} --wait ${waitTime} --json > ${deployLog}"
            )
            echo "Deployment completed. Log: ${deployLog}"
        }

        // -------------------------------
        // 8️⃣ Push updated XML files to GitHub
        // -------------------------------
        stage('Push to GitHub') {
            echo "[STEP] Pushing updated XML files to GitHub..."
            runCommand(
                "git config user.email 'jenkins@example.com' && git config user.name 'Jenkins CI'",
                "git config user.email 'jenkins@example.com' & git config user.name 'Jenkins CI'"
            )

            xmlFilesInput.split(",").each { file ->
                file = file.trim()
                runCommand("git add ${file}", "git add \"${file}\"")
            }

            runCommand(
                "git commit -m 'Updated XML files' || echo 'No changes to commit'",
                "git commit -m \"Updated XML files\" || echo No changes to commit"
            )

            runCommand("git push origin HEAD", "git push origin HEAD")
            echo "Changes pushed to GitHub successfully."
        }

    } catch (err) {
        // -------------------------------
        // Rollback on failure
        // -------------------------------
        echo "[FAILURE] ${err}"
        if(env.BACKUP_FILES) {
            echo "[ROLLBACK] Restoring backups..."
            backupFiles = new groovy.json.JsonSlurperClassic().parseText(env.BACKUP_FILES)
            backupFiles.each { orig, backup ->
                runCommand(
                    "cp ${backup} ${orig}",
                    "copy /Y \"${backup}\" \"${orig}\""
                )
                echo "Restored ${orig} from ${backup}"
            }
        } else {
            echo "[ROLLBACK] No backups to restore"
        }
        error "Pipeline failed and rollback completed"
    }
}
