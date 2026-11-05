import os

from flask import Flask, jsonify
import mysql.connector
import redis

app = Flask(__name__)


@app.get("/live")
def live():
    return jsonify(status="alive")


@app.get("/health")
def health():
    try:
        with mysql.connector.connect(
            host=os.environ["MYSQL_HOST"],
            user=os.environ["MYSQL_USER"],
            password=os.environ["MYSQL_PASSWORD"],
            database=os.environ["MYSQL_DATABASE"],
            connection_timeout=3,
        ) as connection:
            connection.ping()
        redis.Redis(host=os.environ["REDIS_HOST"], socket_connect_timeout=3).ping()
    except (mysql.connector.Error, redis.RedisError, KeyError):
        app.logger.exception("Dependency health check failed")
        return jsonify(status="unavailable"), 503
    return jsonify(status="ready")


@app.get("/")
def index():
    return jsonify(tenant="tenant-d", application="sample-web")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
