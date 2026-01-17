from datetime import datetime, timezone, timedelta
import boto3

ec2 = boto3.client("ec2")
ssm = boto3.client("ssm", region_name="ap-south-1")

INSTANCE_ID = "i-XXXXXXXXXXXX"
PARAM_NAME = "/ec2/shutdown_at"

def lambda_handler(event, context):
    # IST timezone
    ist = timezone(timedelta(hours=5, minutes=30))
    now = datetime.now(ist)

    hour = now.hour

    # --------------------------------------------------
    # 1️⃣ MORNING RULE: Start EC2 at 6:00 AM IST
    # --------------------------------------------------
    if hour == 6:
        print("6 AM reached — starting EC2")
        ec2.start_instances(InstanceIds=[INSTANCE_ID])
        return

    # --------------------------------------------------
    # 2️⃣ NIGHT WINDOW: 11 PM – 2 AM IST
    # --------------------------------------------------
    if hour not in (23, 0, 1):
        return

    # Read shutdown_at from SSM
    try:
        resp = ssm.get_parameter(Name=PARAM_NAME)
        shutdown_at = datetime.fromisoformat(
            resp["Parameter"]["Value"].replace("Z", "+00:00")
        ).astimezone(ist)
    except Exception:
        # If missing or invalid → shutdown immediately
        shutdown_at = now

    if now < shutdown_at:
        return

    print("Shutdown time reached — stopping EC2")
    ec2.stop_instances(InstanceIds=[INSTANCE_ID])
