### Construction brief

We have multiple components involved in this pipeline. To integrate each of them successfully, we will test the pipeline everytime we configure a new component. <br>

The pipeline codes for each integration is located inside `/Jenkins-test-codes` folder of this repository.

### 1. Clone the repository into your local machine 

```
git clone https://github.com/YU88John/vprofile_test.git
```
### 2. Launch EC2 instances for Jenkins, SonarQube and Nexus + Configure Security Groups

#### Console

Instance type: `t2.medium` <br>
AMI: `Ubuntu 22.04`

In `Advanced Options` > `userdata`, please copy the user data provided in the `/userdata` folder for each instance respectively. <br>
*Note:* If you have decided to do local `SSH`, please create key-pairs for each server.

You will need to open these ports on the security group of each instance. If you want to SSH from local machine, you will need to open port `22` too. However, you can perform this action with EC2 instance connect as well.

- Jenkins: `8080, 22`
- SonarQube: `9000, 22`
- Nexus: `8081, 22`

We need to open these ports for browser(UI) access. Each service runs on above-mentioned ports respectively.

#### Terraform

Alternatively, you can create the required instances with terraform. The configuration files are located in `/terraform` folder of this repository. You can read more about Terraform with aws <a href="https://registry.terraform.io/providers/hashicorp/aws/3.9.0/docs">here</a>. <br>

*Note:* You need to supply your own public key in plain text or file path if you plan to create resources with terraform. Please replace the `aws_key_pair` resource values accordingly.

### 3. Setup Jenkins 

After Jenkins server is running, try `SSH` it from your local machine via `Git Bash` or any other unix cli. 
Please ensure Jenkins server is installed
```
sudo systemctl status jenkins
```
Once it shows **RUNNING** you are good to go. 
In case things go wrong and Jenkins server is not up and running, please install it manually using this <a href="https://www.jenkins.io/doc/book/installing/linux/#debianubuntu">documentation</a>. 

Log in to the Jenkins UI with its public IP on port `8080`.
It will show the path where you can get the Administrator password to unlock Jenkins. <br>
Copy the mentioned path, go back to the `SSH` session, and run:
```
sudo cat /var/jenkins_home/secrets/initialAdminPassword
```

**Required Plugins to install in Jenkins**
- `Nexus Artifact Uploader`
- `SonarQube Scanner`
- `Build Timestamp`
- `Pipeline Maven Integration`
- `Slack Notification`
- `Docker Pipeline`
- `Amazon ECR`
- `Amazon Web Services SDK::All`
- `CloudBees Docker Build and Publish`
- `Pipeline: AWS Steps`

#### Integrations 
Integrations have two sides: 
- Jenkins configuration
- Integrating servers configuration


### 4. Setup SonarQube Scanner and Quality Gates

Under `Manage Jenkins`: <br>
`Tools` > `SonarQube Scanner` > `Install automatically` (Please select the latest version, and ensure you remember the name you give) <br>
`Configure System` > `Add SonarQube Server` (In the server URL, paste the Private IP of SonarQube instance prefixed by `http://`) 
  - Since we are using the private connection, we need some form of authentication
  - We will add a token for that authentication
  - By this step, I assume you have logged into SonarQube server already. If not, please login with the default credentials. `admin` for both username and password.
  - In `SonarQube UI` > `My account` > `Tokens` > `Generate Token` (just name it `Jenkins` for classification) Please note the token somewhere safe 
  - Go back to Jenkins UI and add the token as `Secret Text`

We have successfully integrated Jenkins with SonarQube. To ensure this, you can test it by creating a pipeline using the code from `JenkinsfileSQ.groovy`. After this you will see your project in SonarQube as well as its status - `Passed`. 

Code Analysis alone is not enough for production-grade deployment. We need to ensure the source code always meets our desired standards before it proceeds to deployment stage. SonarQube itself has default Quality Gate but **One size never fits all**. For this, we can setup our custom Quality Gates in SonarQube. This is a DevSecOps practice but I will include this in our DevOps pipeline.

`Quality Gates` > `Create` 
- We will set the QG on `overall code`
- The condition will be `Bugs`
- For operator - `Greater than 60`

After creating, go to your project > `Project Settings` > `Quality Gate` and choose your newly created QG

For the Quality Gate to check the code used in our build, we need to create a webhook for Jenkins server and configure networking. <br>
`Project Settings` > `Create Webhook` > `URL` (`http://<JENKINS_PRIVATE_IP>:8080/sonarqube-webhook`) <br>

Go back to AWS console. Add a new inbound rule in Jenkins Security Group, which allows traffic from SonarQube SG on port `8080`.

Ensure the step by creating a new pipeline with the code provided in `JenkinsfileSQqg.groovy`. If the Quality Gate build stage fails, adjust the operator of the Quality Gates based on the results. (eg. If the bugs is 70, increase the operator to a greater value than 70).

### 5. Setup Nexus Artifact repository

Sign in to the Nexus UI using its public IP on port `8081`. Use the default credentials below. (It may ask you to change the password) <br>
- `Username: admin` 
- `Password: admin123` 

Create a new repository which uses `maven2(hosted)` as recipe. To push the artifacts to this repository, we need to configure credentials in Jenkins. <br>

`Manage Jenkins` > `Manage Credentials` > `Jenkins` > `Add Global credentials` (`kind: Username with Password`, fill in your Nexus credentials). <br>
For the version naming, we will simply use `Build Timestamp` plugin. <br>
`Manage Jenkins` > `Configure System` > `Global Properties` > `Build Timestamp` > `Enable` (configure with your preferred layout)


We have successfully integrated Jenkins with Nexus Artifact Repository. To ensure this, you can test it by creating a pipeling with `JenkinsfileNX.groovy`. Make sure to replace the placeholders with your actual values. <br>
After a successful build, you will see your artifact uploaded to your repository. If you build again, there will be another different artifact with different timestamp. 


### 6. Setup Slack for build notifications

If you have existing Slack workspace, create a channel where Jenkins will send build notifications (e.g. Succeed or Fail). Ensure the `Automatically add anyone who joins <CHANNEL>` is enabled. <br>

Please go to this <a href="https://slack.com/apps">link</a>, sign in to your workspace and choose your channel. Please follow the steps that it provides for integration. The connection test will show `SUCCESS` if you implemented everything correctly. 

Now, you can test the integration by building a new pipeline using `JenkinsfileSlack.groovy`. Make sure you replace the placeholders with your actual values. 

### 7. Setup AWS ECR 

Before we set up ECR, we first need Docker engine and aws cli inside Jenkins server for building container images and pushing them to ECR.

`SSH` into Jenkins server. <br>
Install `aws cli`
```
sudo apt update && sudo apt install aws-cli -y
```
Install Docker engine
```
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```
```
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Test run Docker
```
sudo docker run hello-world
```
Add Jenkins user into Docker group
```
sudo usermod -a -G docker jenkins
```
```
reboot
```

**Create IAM user for aws cli**

For Jenkins to access ECR and ECS programatically, we need an IAM user with required permissions. <br>
Go to AWS console and Create an IAM user with the following permissions:
- `AmazonECS_FullAccess`
- `AmazonEC2ContainerRegistryFullAccess`

After you created the user, create access keys for that user. <br>
`User` > `Security Credentials` > `Create access key` > `command line interface(cli)` > `Create` <br>
Download the `.csv` file or copy the values to somewhere safe. *These values will not appear again.* 

**Create ECR and ECS**

Go to AWS console > `Amazon ECR` > `Create Repository` with the following details <br>
- `Private`
- `Name: devops`

Afterwards, setup AWS credentials inside Jenkins. 
`Manage Jenkins` > `Manage Credentials` > `Jenkins` > `Add Global credentials` (`kind: AWS Credentials`, fill in your `Access Key ID` and `Secret Access Key`) <br>

Test your integrations with `JenkinsfileECRtest.groovy` by replacing placeholders with your values.

### 8. Setup AWS ECS

In the AWS console: <br>
Create ECS cluster. <br>
`Amazon Elastic Container Service` > `Clusters` > `Create cluster` <br>
- Name: `devopscluster`
- Infrastructure: `AWS Fargate (serverless)`
- Monitoring: `Use Container Insights`

Create Task definition. <br>
To deploy containers on the ECS cluster, we need task definitions. <br>
- Task definition family: `devopstask`
- Launch type: `AWS Fargate`
- Operating system: `Linux/x86_64` 
- Task size: `1 vCPU, 2 GB`
- Task execution role: `Create new role` 
<br>
  Container details:
  - name: `devops`
  - Image URI: `PASTE YOUR ECR REPO URI`
  - Container port: `8080`
  - Monitoring: `Use log collection`


Create Service. <br>
- Application type: `Service`
- Family `devopstask`
- Revision: `LATEST`
- Name: `devopsvc`
- Desired tasks: 1
- Disable deployment failure detection <br>
- Create a new security group. <br>
  - Allow `HTTP` and port `8080` from anywhere. 
- Load Balancer > Application Load balancer 
  - Listener port: `80`
  - Create new target group
    - Name: `devopstg`
    - Health check path: `login`

Since we enable monitoring, we need to add permissions to the task execution role. Please add `CloudWatchLogsFullAccess` accordingly. 

Test the deployment with `JenkinsfileECS.groovy` by replacing placeholders with your actual values. <br>
This will build a new image and subsequently deploy that image to the ECS cluster.

### 9. Construct an automated CI/CD pipeline

Until now, what we have done is integrating all the necessary components for the pipeline. It is time to construct an automated pipeline with those integrations, which will deploy the application based on `push` actions of the GitHub repository. 

Create a new private GitHub repository and clone it into your local machine via SSH. 
```
git clone YOUR_REPO_LINK
```
Add your public `SSH key` to your GitHub account. 
```
ssh-keygen.exe
cat /.ssh/id_rsa.pub
```
Go to your GitHub account settings. <br>
`SSH and GPG keys` > `Title: My local machine` > Paste your public `ssh key` as `Key`.

Copy the `Jenkinsfile` from my repository to your local repository directory.
```
cp -r Jenkinsfile YOUR_REPO_LINK
```

Stage and push the `Jenkinsfile` to your repository.
```
git add -A
git commit -m "First commit"
git push origin main
```

**Add your ssh credentials to Jenkins** <br>
`Manage Jenkins` > `Manage Credentials` > `Jenkins` > `Add Global credentials` (`kind: SSH Username with private key`, fill in your `GitHub username` and `private ssh key` from `/.ssh/id_rsa`) <br>

**Add Git trigger** <br>
Go to your *repository* settings. <br>
`Webhooks` > `Add webhook` 
- `Payload URL`: `http://YOUR_JENKINS_URL/github-webhook/`
- `Content type`: `application/json`
- `Events`: `push` event <br>

After creation, you will see the success of your delivery. If it fails, check the Jenkins Security Group if it allows `8080` from `0.0.0.0/0`. 

**Set your repository as source** <br>
`Pipeline` > `Definition` > `Pipeline script from SCM` > `SCM = git` > Paste your repository `SSH` URL > Choose your previously created `ssh credentials` > `Script path = Jenkins` > `Create`<br>
Configure your pipeline triggers: <br>
`Configure` > `Build Triggers` > `GitHub hook trigger from GITScm polling`

**Test trigger** <br>
Make sure you are in the local clone repository directory. <br>
Create a text file. 
```
touch hello-world.txt
echo "Hello World" > hello-world.txt
```
Push it to the repository.
```
git add -A
git commit -m "test trigger"
git push origin main
```

As soon as you pushed the text file to the `main` branch, it will trigger Jenkins to build the pipeline. This also triggers all the sequential events, finally deploying the application to AWS ECS cluster.

Jenkins is also rich of other features, such as Scheduled based and remote triggers. You can test these features under `Build Triggers`. I will also try to develop a detailed documentation to test `Remote Triggers`, which is a very useful feature.

***
## Project Outcomes

In this project, we learned how to build a Jenkins pipeline that got triggered by every push event to the `main` branch of the repository. We also learnt how important it is to ensure the quality of the code before deploying it to the production workloads. <br> 

It is the best to create two pipelines for `prod` and `dev` environments. In this way, we can test the changes in `dev` envrionment first and then merge it to `prod` or `main` branch when we are satisfied. I implemented such architecture in my GCP DevOps project, which is available <a href="https://github.com/YU88John/gcp-devops-project">here</a>.




















