terraform output -json | python3 -c "
import sys, json

data = json.load(sys.stdin)

def get_value(key):
    return data.get(key, {}).get('value', '')

env_content = f'''# Open edX Terraform outputs as environment variables

ELASTICSEARCH_HOST={get_value('elasticsearch_endpoint')}
MONGODB_HOST={get_value('mongodb_endpoint')}
MONGODB_PORT={get_value('mongodb_port')}
MYSQL_PORT={get_value('mysql_port')}
MYSQL_HOST={get_value('mysql_host')}
MYSQL_DATABASE={get_value('mysql_database')}
REDIS_HOST={get_value('redis_endpoint')}
REDIS_PORT={get_value('redis_port')}
S3_BUCKET={get_value('s3_bucket_name')}
MONGODB_USERNAME={get_value('mongodb_username')}
MONGODB_PASSWORD='{get_value('mongodb_password')}'
MYSQL_USERNAME={get_value('mysql_username')}
MYSQL_PASSWORD='{get_value('mysql_password')}'
AWS_REGION={get_value('aws_region')}
CLUSTER_NAME={get_value('cluster_name')}
'''

print(env_content)
" > ../../../.env