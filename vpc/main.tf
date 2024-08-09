terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

# vpc 정의
resource "aws_vpc" "this" {
    cidr_block = "10.50.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support = true
    tags = {
        Name = "eks-vpc"
    }
}


# IGW 생성
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "eks-vpc-igw"
  }

}


# vpc와 IGW 연결


# NATGW를 위한 탄력적IP 생성
resource "aws_eip" "this" {
    lifecycle {
        create_before_destroy = true 
        # 재생성 시 먼저 새 리소스(EIP) 만들고, 기존 리소스 삭제
        # 롤링 업뎃이라고 생각하면 됨
    }

    tags = {
        Name = "eks-vpc-eip"
    }
  
}



# Public Subnet 생성
resource "aws_subnet" "pub_sub1" {
    vpc_id = aws_vpc.this.id #위에서 aws_vpc라는 리소스로 만든 this라는 리소스의 id
    cidr_block = "10.50.10.0/24"
    map_public_ip_on_launch = true
    enable_resource_name_dns_a_record_on_launch = true
    availability_zone = "ap-northeast-2a"
    tags = {
        Name = "pub-sub1"
        "kubernetes.io/cluster/pri-cluster" = "owned"
        "kuberntest.io/role/elb" = "1"
   
    }
    depends_on = [ aws_internet_gateway.this ]
}

resource "aws_subnet" "pub_sub2" {
    vpc_id = aws_vpc.this.id #위에서 aws_vpc라는 리소스로 만든 this라는 리소스의 id
    cidr_block = "10.50.11.0/24"
    map_public_ip_on_launch = true
    enable_resource_name_dns_a_record_on_launch = true
    availability_zone = "ap-northeast-2c"
    tags = {
        Name = "pub-sub2"
        "kubernetes.io/cluster/pri-cluster" = "owned"
        "kuberntest.io/role/elb" = "1"
   
    }
    depends_on = [ aws_internet_gateway.this ]
}


# NATGW 생성

resource "aws_nat_gateway" "this" {
    allocation_id = aws_eip.this.id
    subnet_id = aws_subnet.pub_sub1.id
    tags = {
        Name = "eks-vpc-natgw"
    }
    lifecycle {
      create_before_destroy = true
    }
}


# Private Subnet 생성
resource "aws_subnet" "pri_sub1" {
    vpc_id = aws_vpc.this.id #위에서 aws_vpc라는 리소스로 만든 this라는 리소스의 id
    cidr_block = "10.50.20.0/24"
    enable_resource_name_dns_a_record_on_launch = true
    availability_zone = "ap-northeast-2a"
    tags = {
        Name = "pri-sub1"
        "kubernetes.io/cluster/pri-cluster" = "owned"
        "kubernetes.io/role/elb" = "1"
   
    }
    depends_on = [ aws_internet_gateway.this ]
}

resource "aws_subnet" "pri_sub2" {
    vpc_id = aws_vpc.this.id #위에서 aws_vpc라는 리소스로 만든 this라는 리소스의 id
    cidr_block = "10.50.21.0/24"
    enable_resource_name_dns_a_record_on_launch = true
    availability_zone = "ap-northeast-2c"
    tags = {
        Name = "pri-sub2"
        "kubernetes.io/cluster/pri-cluster" = "owned"
        "kubernetes.io/role/elb" = "1"
   
    }
    depends_on = [ aws_internet_gateway.this ]
}


# Public Routing Table 정의
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "10.50.0.0/16"
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    Name = "eks-vpc-pub-rt"
  }
}



# Private Routing Table 정의
resource "aws_route_table" "pri_rt" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "10.50.0.0/16"
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "eks-vpc-pri-rt"
  }
}



# 퍼블릭 라우팅테이블과 퍼블릭 서브넷을 연결


resource "aws_route_table_association" "pu1_rt_asso" {
    subnet_id = aws_subnet.pub_sub1.id
    route_table_id = aws_route_table.pub_rt.id
}


resource "aws_route_table_association" "pub2_rt_asso" {
    subnet_id = aws_subnet.pub_sub2.id
    route_table_id = aws_route_table.pub_rt.id
}


# 퍼블릭 라우팅테이블과 퍼블릭 서브넷을 연결


resource "aws_route_table_association" "pri1_rt_asso" {
    subnet_id = aws_subnet.pri_sub1.id
    route_table_id = aws_route_table.pri_rt.id
}


resource "aws_route_table_association" "pri2_rt_asso" {
    subnet_id = aws_subnet.pri_sub2.id
    route_table_id = aws_route_table.pri_rt.id
}



# 보안그룹 생성

resource "aws_security_group" "eks-vpc-pub-sg" {
    vpc_id = aws_vpc.this.id
    name = "eks-vpc-pub-sg"
    tags = {
        Name = "eks-vpc-pub-sg"
    }
}


# Ingress 규칙 : HTTP 허용

resource "aws_security_group_rule" "eks-vpc-http-Ingress" {
    type = "ingress"
    from_port = 80
    to_port = 80
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.eks-vpc-pub-sg.id
    lifecycle {
      create_before_destroy = true
    }
}

# Ingress 규칙 SSH 허용

resource "aws_security_group_rule" "eks-vpc-ssh-ingress" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.eks-vpc-pub-sg.id
    lifecycle {
      create_before_destroy = true
    }
}


# Egress 규칙
