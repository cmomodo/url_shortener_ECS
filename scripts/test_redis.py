#!/usr/bin/env python3
"""
Spins up a temp EC2 bastion in the VPC, tests ElastiCache Redis, then cleans up.
Usage: python3 scripts/test_redis.py
"""

import boto3
import os
import time
import subprocess
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
ENV_PATH = ROOT_DIR / ".env"


def load_env_file(env_path):
    if not env_path.exists():
        return

    for raw_line in env_path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def get_required_env(name):
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


load_env_file(ENV_PATH)

REGION = get_required_env("REDIS_TEST_AWS_REGION")
VPC_ID = get_required_env("REDIS_TEST_VPC_ID")
KEY_NAME = get_required_env("REDIS_TEST_KEY_NAME")
KEY_PATH = get_required_env("REDIS_TEST_KEY_PATH")
REDIS_HOST = get_required_env("REDIS_TEST_HOST")
REDIS_PORT = int(get_required_env("REDIS_TEST_PORT"))
AMI_ID = get_required_env("REDIS_TEST_AMI_ID")
INSTANCE_TYPE = get_required_env("REDIS_TEST_INSTANCE_TYPE")
ECS_TASKS_SECURITY_GROUP_NAME = get_required_env("REDIS_TEST_ECS_SECURITY_GROUP_NAME")
TEST_KEY = get_required_env("REDIS_TEST_KEY")
TEST_VALUE = get_required_env("REDIS_TEST_VALUE")
TEST_TTL_SECONDS = int(get_required_env("REDIS_TEST_TTL_SECONDS"))

if not os.path.isabs(KEY_PATH):
    KEY_PATH = str((ROOT_DIR / KEY_PATH).resolve())

ec2 = boto3.client("ec2", region_name=REGION)

def create_security_group():
    print("Creating temp security group...")
    sg = ec2.create_security_group(
        GroupName="redis-bastion-temp",
        Description="Temp bastion for Redis testing",
        VpcId=VPC_ID,
    )
    sg_id = sg["GroupId"]
    ec2.authorize_security_group_ingress(
        GroupId=sg_id,
        IpPermissions=[{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22,
                        "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}],
    )
    print(f"Security group created: {sg_id}")
    return sg_id

def find_public_subnet():
    print("Finding a public subnet that supports the bastion instance type...")
    subnets = ec2.describe_subnets(
        Filters=[{"Name": "vpc-id", "Values": [VPC_ID]}]
    )["Subnets"]
    public_subnets = [subnet for subnet in subnets if subnet.get("MapPublicIpOnLaunch")]
    if not public_subnets:
        raise RuntimeError(f"No public subnets found in VPC {VPC_ID}")

    supported_azs = {
        offering["Location"]
        for offering in ec2.describe_instance_type_offerings(
            LocationType="availability-zone",
            Filters=[{"Name": "instance-type", "Values": [INSTANCE_TYPE]}],
        )["InstanceTypeOfferings"]
    }
    matching_subnets = [
        subnet for subnet in public_subnets
        if subnet["AvailabilityZone"] in supported_azs
    ]
    if not matching_subnets:
        raise RuntimeError(
            f"No public subnets found in a supported AZ for {INSTANCE_TYPE}"
        )

    matching_subnets.sort(key=lambda subnet: subnet["AvailabilityZone"])
    subnet_id = matching_subnets[0]["SubnetId"]
    az = matching_subnets[0]["AvailabilityZone"]
    print(f"Using subnet {subnet_id} in {az}")
    return subnet_id

def launch_instance(sg_id):
    subnet_id = find_public_subnet()
    print("Launching EC2 bastion...")
    resp = ec2.run_instances(
        ImageId=AMI_ID,
        InstanceType=INSTANCE_TYPE,
        KeyName=KEY_NAME,
        MinCount=1, MaxCount=1,
        NetworkInterfaces=[{
            "DeviceIndex": 0,
            "SubnetId": subnet_id,
            "Groups": [sg_id],
            "AssociatePublicIpAddress": True,
        }],
        TagSpecifications=[{"ResourceType": "instance",
                            "Tags": [{"Key": "Name", "Value": "redis-test-bastion"}]}],
    )
    instance_id = resp["Instances"][0]["InstanceId"]
    print(f"Instance launched: {instance_id}, waiting for it to be running...")
    waiter = ec2.get_waiter("instance_running")
    waiter.wait(InstanceIds=[instance_id])
    desc = ec2.describe_instances(InstanceIds=[instance_id])
    public_ip = desc["Reservations"][0]["Instances"][0]["PublicIpAddress"]
    print(f"Instance running at {public_ip}")
    return instance_id, public_ip

def allow_redis_from_bastion(sg_id):
    print("Allowing Redis access from bastion security group...")
    # Allow port 6379 from bastion sg on the ecs_tasks sg
    sgs = ec2.describe_security_groups(
        Filters=[{"Name": "group-name", "Values": [ECS_TASKS_SECURITY_GROUP_NAME]}]
    )
    ecs_sg_id = sgs["SecurityGroups"][0]["GroupId"]
    try:
        ec2.authorize_security_group_ingress(
            GroupId=ecs_sg_id,
            IpPermissions=[{
                "IpProtocol": "tcp", "FromPort": 6379, "ToPort": 6379,
                "UserIdGroupPairs": [{"GroupId": sg_id}],
            }],
        )
        print(f"Redis port 6379 opened on {ecs_sg_id} for bastion")
    except ec2.exceptions.ClientError as e:
        if "InvalidPermission.Duplicate" in str(e):
            print("Redis rule already exists, skipping")
        else:
            raise
    return ecs_sg_id

def test_redis(public_ip):
    if not os.path.exists(KEY_PATH):
        raise FileNotFoundError(f"SSH key not found: {KEY_PATH}")

    commands = (
        f"(sudo amazon-linux-extras install -y redis6 || sudo yum install -y redis6) && "
        f"redis-cli -h {REDIS_HOST} -p {REDIS_PORT} PING && "
        f"redis-cli -h {REDIS_HOST} -p {REDIS_PORT} SET {TEST_KEY} '{TEST_VALUE}' EX {TEST_TTL_SECONDS} && "
        f"redis-cli -h {REDIS_HOST} -p {REDIS_PORT} GET {TEST_KEY} && "
        f"redis-cli -h {REDIS_HOST} -p {REDIS_PORT} KEYS 'url:*'"
    )
    ssh = [
        "ssh", "-o", "StrictHostKeyChecking=no",
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=10",
        "-i", KEY_PATH,
        f"ec2-user@{public_ip}",
        commands,
    ]
    print("\nWaiting for SSH to be ready...")
    for attempt in range(1, 7):
        if attempt > 1:
            time.sleep(10)
        print(f"\n--- Redis Test Output (attempt {attempt}/6) ---")
        result = subprocess.run(ssh)
        if result.returncode == 0:
            return
        if result.returncode != 255:
            raise subprocess.CalledProcessError(result.returncode, ssh)
    raise RuntimeError("SSH never became ready for the bastion instance")

def cleanup(instance_id, sg_id, ecs_sg_id):
    print("\nCleaning up...")
    if instance_id:
        ec2.terminate_instances(InstanceIds=[instance_id])
        print(f"Terminating instance {instance_id}...")
        waiter = ec2.get_waiter("instance_terminated")
        waiter.wait(InstanceIds=[instance_id])
    if ecs_sg_id and sg_id:
        try:
            ec2.revoke_security_group_ingress(
                GroupId=ecs_sg_id,
                IpPermissions=[{
                    "IpProtocol": "tcp", "FromPort": 6379, "ToPort": 6379,
                    "UserIdGroupPairs": [{"GroupId": sg_id}],
                }],
            )
        except Exception:
            pass
    if sg_id:
        ec2.delete_security_group(GroupId=sg_id)
    print("Cleanup complete.")

def main():
    sg_id = None
    instance_id = None
    ecs_sg_id = None
    try:
        sg_id = create_security_group()
        ecs_sg_id = allow_redis_from_bastion(sg_id)
        instance_id, public_ip = launch_instance(sg_id)
        test_redis(public_ip)
    finally:
        if sg_id:
            cleanup(instance_id, sg_id, ecs_sg_id)

if __name__ == "__main__":
    main()
