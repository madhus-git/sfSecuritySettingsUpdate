node {
    try {
        // ===============================
        // 1️⃣ Define build parameters
        // ===============================
        properties([
            parameters([
                string(name: 'SETTINGS_FILE_PATTERN', defaultValue: 'Security.settings-meta.xml', description: 'Settings XML file pattern'),
                string(name: 'UPDATE_KEYS', defaultValue: 'canUsersGrantLoginAccess,enableAdminLoginAsAnyUser', description: 'Comma-separated XML nodes to update'),
                string(name: 'UPDATE_VALUES', defaultValue: 'true,false', description: 'Comma-separated values for the nodes'),
                string(name: 'DEPLOY_ORG_ALIAS', defaultValue: 'devOrg', description: 'Salesforce org alias to deploy to'),
                string(name: 'GIT_BRANCH', defaultValue: 'main', description: 'Git branch to commit updates')
            ])
        ])

        // ===============================
        // 2️⃣ Checkout the code
        // ===============================
        stage('Checkout') {
            checkout([$class: 'GitSCM', branches: [[name: params.GIT_BRANCH]],
                      userRemoteConfigs: [[url: 'https://your-repo.git']]])
        }

        // ===============================
        // 3️⃣ Backup original files (for rollback)
        // ===============================
        stage('Backup Original XMLs') {
            def xmlFiles = findFiles(glob: "force-app/main/default/settings/${params.SETTINGS_FILE_PATTERN}")
            if (xmlFiles.length == 0) error "No files found for pattern: ${params.SETTINGS_FILE_PATTERN}"

            xmlFiles.each { f ->
                def origFile = new File(f.path)
                def backupFile = new File(f.path + ".bak")
                backupFile.text = origFile.text
                println "Backup created for: ${f.path}"
            }
        }

        // ===============================
        // 4️⃣ Update XML Files
        // ===============================
        stage('Update XML') {
            def xmlFiles = findFiles(glob: "force-app/main/default/settings/${params.SETTINGS_FILE_PATTERN}")
            
            def keys = params.UPDATE_KEYS.split(',')
            def values = params.UPDATE_VALUES.split(',')
            if (keys.size() != values.size()) error "UPDATE_KEYS and UPDATE_VALUES must have same number of items"

            def updateMap = [:]
            keys.eachWithIndex { k, i -> updateMap[k] = values[i] }

            // Update each XML file
            xmlFiles.each { f ->
                println "Updating XML file: ${f.path}"
                def file = new File(f.path)
                def xml = new XmlParser().parse(file)

                // Track updated nodes for validation
                def updatedNodes = [:]

                updateMap.each { k, v ->
                    def node = xml."${k}"
                    if (node) {
                        node[0].value = v
                        updatedNodes[k] = node[0].value
                        println "Updated ${k} -> ${v}"
                    } else {
                        xml.appendNode(k, v)
                        updatedNodes[k] = v
                        println "Added node ${k} -> ${v}"
                    }
                }

                // Write back XML
                def writer = new FileWriter(file)
                def printer = new XmlNodePrinter(new PrintWriter(writer))
                printer.setPreserveWhitespace(true)
                printer.print(xml)
                writer.close()

                // Validation
                def xmlAfter = new XmlParser().parse(file)
                keys.each { k ->
                    def nodeValue = xmlAfter."${k}" ? xmlAfter."${k}"[0].text() : null
                    if (nodeValue != updateMap[k]) error "Validation failed for ${k} in file ${f.path}. Expected: ${updateMap[k]}, Found: ${nodeValue}"
                }
                println "Validation passed for file: ${f.path}"
            }
        }

        // ===============================
        // 5️⃣ Deploy to Salesforce Org using SF CLI
        // ===============================
        stage('Deploy to Org') {
            def xmlFiles = findFiles(glob: "force-app/main/default/settings/${params.SETTINGS_FILE_PATTERN}")
            def filesToDeploy = xmlFiles.collect { it.path }.join(' ')
            if (!filesToDeploy) error "No files found to deploy"

            echo "Deploying files to org: ${params.DEPLOY_ORG_ALIAS}"
            def deployResult = bat(script: "sfdx force:source:deploy -p ${filesToDeploy} -u ${params.DEPLOY_ORG_ALIAS} --wait 10 --testlevel NoTestRun", returnStatus: true)

            if (deployResult != 0) {
                error "Deployment failed! Rolling back XML changes..."
            }
            echo "Deployment succeeded!"
        }

        // ===============================
        // 6️⃣ Commit updates to Git
        // ===============================
        stage('Commit Updates') {
            bat """
                git config user.email "jenkins@yourdomain.com"
                git config user.name "Jenkins"
                git checkout ${params.GIT_BRANCH}
                git add force-app/main/default/settings/${params.SETTINGS_FILE_PATTERN}
                git commit -m "Updated settings XML via Jenkins build"
                git push origin ${params.GIT_BRANCH}
            """
        }

        echo "Pipeline completed successfully!"

    } catch (err) {
        // ===============================
        // 7️⃣ Rollback changes if deployment fails
        // ===============================
        stage('Rollback Changes') {
            echo "Rolling back XML changes..."
            def xmlFiles = findFiles(glob: "force-app/main/default/settings/${params.SETTINGS_FILE_PATTERN}")
            xmlFiles.each { f ->
                def backupFile = new File(f.path + ".bak")
                if (backupFile.exists()) {
                    new File(f.path).text = backupFile.text
                    println "Restored backup for: ${f.path}"
                }
            }
        }

        currentBuild.result = 'FAILURE'
        throw err
    }
}
