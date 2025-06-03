resource "aws_instance" "Jenkins" {
    ami                     = var.ami_id
    instance_type           = var.instance_size

    tags = {
        Name = "Jenkins"
    }

    vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

    user_data = file("${path.module}/jenkins-userdata.sh")
}

resource "aws_instance" "SonarQube" {
    ami                     = var.ami_id
    instance_type           = var.instance_size

    tags = {
        Name = "SonarQube"
    }

    vpc_security_group_ids = [aws_security_group.sonarqube_sg.id]

    user_data = file("${path.module}/sonarqube-userdata.sh")
}

resource "aws_instance" "Nexus" {
    ami                     = var.ami_id
    instance_type           = var.instance_size

    tags = {
        Name = "Nexus"
    }

    vpc_security_group_ids = [aws_security_group.nexus_sg.id]

    user_data = file("${path.module}/nexus-userdata.sh") 

}

// Keypairs configs - PLEASE REPLACE YOUR VALUES

resource "aws_key_pair" "jenkins-kp" {
    key_name = "jenkins-key"
    public_key = file("/root/.ssh/jenkins.pub")
}

// Security groups configs

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Security group for Jenkins instance"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sonarqube_sg" {
  name        = "sonarqube-sg"
  description = "Security group for SonarQube instance"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nexus_sg" {
  name        = "nexus-sg"
  description = "Security group for Nexus instance"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
