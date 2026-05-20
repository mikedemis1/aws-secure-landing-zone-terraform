resource "aws_subnet" "public" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-west-1a"
    tags = {
    Name = "public-subnet"  }

  
}

resource "aws_subnet" "private"{
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "private-subnet"
  }

}