module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.26.6"
  cluster_name = "pri-cluster"
  cluster_version = "1.29"

  vpc_id = var.eks-vpc-id

  subnet_ids = [
    var.pri-sub1-id,
    var.pri-sub2-id
    # 일단 변수만 선언해두고, 나중에 vpc 모듈에서 뽑아낸 output 값을 넣어줄 것
  ]

  eks_managed_node_groups = {
    pri-cluster-nodegroups = {
        min_size = 1
        max_size = 4
        desired_size = 1
        instance_types = ["t3.mirco"]
    }
  }

  cluster_endpoint_private_access = true
}

