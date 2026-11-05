import os
import unittest
from unittest.mock import MagicMock, patch

import app
import mysql.connector
import redis


class WebTests(unittest.TestCase):
    def setUp(self):
        self.client = app.app.test_client()

    def test_index_and_liveness(self):
        self.assertEqual(self.client.get("/").json["tenant"], "tenant-d")
        self.assertEqual(self.client.get("/live").status_code, 200)

    @patch.dict(os.environ, {
        "MYSQL_HOST": "mysql", "MYSQL_USER": "app", "MYSQL_PASSWORD": "test-only",
        "MYSQL_DATABASE": "app", "REDIS_HOST": "redis",
    })
    @patch("app.redis.Redis")
    @patch("app.mysql.connector.connect")
    def test_ready_checks_database_and_redis(self, connect, redis_client):
        connection = MagicMock()
        connect.return_value.__enter__.return_value = connection
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        connection.ping.assert_called_once()
        redis_client.return_value.ping.assert_called_once()

    @patch.dict(os.environ, {
        "MYSQL_HOST": "mysql", "MYSQL_USER": "app", "MYSQL_PASSWORD": "test-only",
        "MYSQL_DATABASE": "app", "REDIS_HOST": "redis",
    })
    @patch("app.mysql.connector.connect", side_effect=mysql.connector.Error("unavailable"))
    def test_database_failure_is_not_reported_as_success(self, connect):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json["status"], "unavailable")

    @patch.dict(os.environ, {
        "MYSQL_HOST": "mysql", "MYSQL_USER": "app", "MYSQL_PASSWORD": "test-only",
        "MYSQL_DATABASE": "app", "REDIS_HOST": "redis",
    })
    @patch("app.redis.Redis", side_effect=redis.RedisError("unavailable"))
    @patch("app.mysql.connector.connect")
    def test_redis_failure_is_not_reported_as_success(self, connect, redis_client):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json["status"], "unavailable")


if __name__ == "__main__":
    unittest.main()
