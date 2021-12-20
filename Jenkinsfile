pipeline {
    agent any
    stages{
        stage('git-checkout') {
            agent any
            steps {
                git branch: 'master', url: 'https://github.com/jalogut/jenkinsfile-basic-sample.git'
            }
        }
        stage('list-objects') {
            agent any
            steps {
                sh '''#!/bin/bash
            
                    ls -ltrt
                    pwd
                '''
            }
         }
    }
}
