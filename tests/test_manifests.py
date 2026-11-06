import pathlib
import unittest

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]


def build(chart):
    manifest = ROOT / "kubernetes" / "dist" / chart / "manifest.k8s.yaml"
    return list(yaml.safe_load_all(manifest.read_text(encoding="utf-8")))


def resource(docs, kind, name):
    found = [x for x in docs if x["kind"] == kind and x["metadata"]["name"] == name]
    if len(found) != 1:
        raise AssertionError(f"Expected one {kind}/{name}, got {len(found)}")
    return found[0]


class ManifestTests(unittest.TestCase):
    def test_tenants_default_deny_and_dns(self):
        for letter in "abcd":
            with self.subTest(tenant=letter):
                docs = build(f"tenant-{letter}")
                ns = f"tenant-{letter}"
                resource(docs, "Namespace", ns)
                deny = resource(docs, "NetworkPolicy", "default-deny")
                self.assertEqual(set(deny["spec"]["policyTypes"]), {"Ingress", "Egress"})
                self.assertEqual(deny["metadata"]["namespace"], ns)
                policy = resource(docs, "NetworkPolicy", "same-tenant-and-dns")
                self.assertEqual(policy["metadata"]["namespace"], ns)
                self.assertEqual(policy["spec"]["egress"][0]["to"], [{"podSelector": {}}])
                self.assertEqual(policy["spec"]["egress"][1]["ports"], [
                    {"protocol": "UDP", "port": 53},
                    {"protocol": "TCP", "port": 53},
                ])

    def test_immich_persistent_data_uses_ceph_rbd(self):
        docs = build("tenant-a")
        for name in ("immich-media", "immich-ml-cache", "immich-postgres"):
            with self.subTest(pvc=name):
                claim = resource(docs, "PersistentVolumeClaim", name)
                self.assertEqual(claim["spec"]["storageClassName"], "ceph-rbd")
                self.assertEqual(claim["spec"]["accessModes"], ["ReadWriteOnce"])
                self.assertNotIn("volumeName", claim["spec"])

    def test_web_ingress_is_limited_to_ingress_namespace(self):
        for letter, name in [("a", "immich-http"), ("c", "nextcloud-http"), ("d", "web-http")]:
            with self.subTest(tenant=letter):
                docs = build(f"tenant-{letter}")
                policy = resource(docs, "NetworkPolicy", name)
                self.assertEqual(policy["spec"]["ingress"][0]["from"], [
                    {"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "ingress-system"}}}
                ])

    def test_external_db_overlay(self):
        docs = build("tenant-c-external-db")
        self.assertFalse(any(x["kind"] == "Deployment" and x["metadata"]["name"] == "mysql" for x in docs))
        app = resource(docs, "Deployment", "nextcloud")
        env = app["spec"]["template"]["spec"]["containers"][0]["env"]
        self.assertEqual(next(x["value"] for x in env if x["name"] == "MYSQL_HOST"), "mysql-external")
        external = resource(docs, "Service", "mysql-external")
        self.assertEqual(external["spec"]["type"], "ExternalName")
        policy = resource(docs, "NetworkPolicy", "allow-external-mysql")
        self.assertEqual(policy["spec"]["egress"][0]["to"][0]["ipBlock"]["cidr"], "172.28.103.10/32")
        self.assertEqual(policy["spec"]["egress"][0]["ports"][0]["port"], 3306)

    def test_other_external_db_overlays(self):
        for letter, deployment, container, env_key, target, db_name, port in [
            ("a", "immich", "immich", "DB_HOSTNAME", "postgres-external", "postgres", 5432),
            ("d", "web", "web", "MYSQL_HOST", "mysql-external", "mysql", 3306),
        ]:
            with self.subTest(tenant=letter):
                docs = build(f"tenant-{letter}-external-db")
                self.assertFalse(any(x["kind"] == "Deployment" and x["metadata"]["name"] == db_name for x in docs))
                app = resource(docs, "Deployment", deployment)
                containers = app["spec"]["template"]["spec"]["containers"]
                env = next(c["env"] for c in containers if c["name"] == container)
                self.assertEqual(next(x["value"] for x in env if x["name"] == env_key), target)
                self.assertEqual(resource(docs, "Service", target)["spec"]["type"], "ExternalName")
                policy = resource(docs, "NetworkPolicy", f"allow-external-{db_name}")
                self.assertEqual(policy["spec"]["egress"][0]["ports"][0]["port"], port)

    def test_management_writes_disabled_and_no_public_service(self):
        docs = build("admin")
        app = resource(docs, "Deployment", "tenant-admin")
        env = app["spec"]["template"]["spec"]["containers"][0]["env"]
        self.assertEqual(next(x["value"] for x in env if x["name"] == "PLATFORM_WRITES_ENABLED"), "false")
        service = resource(docs, "Service", "tenant-admin")
        self.assertNotIn(service["spec"].get("type"), ["NodePort", "LoadBalancer"])

    def test_argocd_points_to_independent_tenant_charts(self):
        appset = resource(build("argocd"), "ApplicationSet", "tenant-samples")
        elements = appset["spec"]["generators"][0]["list"]["elements"]
        self.assertEqual(elements, [
            {"name": f"tenant-{letter}", "path": f"kubernetes/dist/tenant-{letter}"}
            for letter in "abcd"
        ])
        for element in elements:
            docs = build(element["name"])
            resource(docs, "Namespace", element["name"])
            self.assertTrue(all(
                doc["metadata"].get("namespace", element["name"]) == element["name"]
                for doc in docs
            ))

    def test_external_db_removes_local_database_resources(self):
        for letter, db, claim in [
            ("a", "postgres", "immich-postgres"),
            ("c", "mysql", "mysql-data"),
            ("d", "mysql", "mysql-data"),
        ]:
            with self.subTest(tenant=letter):
                docs = build(f"tenant-{letter}-external-db")
                for kind, name in [("Deployment", db), ("Service", db), ("PersistentVolumeClaim", claim)]:
                    self.assertFalse(any(
                        doc["kind"] == kind and doc["metadata"]["name"] == name for doc in docs
                    ))


if __name__ == "__main__":
    unittest.main()
