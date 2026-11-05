# Laravel 管理画面

Laravel 13 ベースの実験用管理画面です。Kubernetes API に直接アクセスして、ラベル付き namespace 一覧、新規 namespace と基本 NetworkPolicy の作成、この画面で作成した namespace の削除要求を行います。**テナントアプリ、DB、VM、RBAC、バックアップ、DNS、GitOps リポジトリは管理しません**。A〜D は別途生成済み YAML を `kubectl apply -f` で作成します。

## 重要な安全制約

- Deployment の `PLATFORM_WRITES_ENABLED` は既定で `false`。管理者が十分に確認して明示的に `true` に変えない限り書き込みできません。
- Basic 認証を使用します。暗号化なしでネットワーク公開しないでください。初期確認は `kubectl port-forward` でローカルのみとし、運用する場合は TLS・認証基盤・アクセス制限・監査・レート制限が必要です。
- サービスアカウントには cluster-scoped namespace の作成・削除権限と全 namespace の NetworkPolicy 作成権限が必要です。**Kubernetes RBAC はラベルで namespace の削除権限を制限できないため**、アプリのラベル・確認入力チェックは侵害時の安全境界ではありません。実験専用クラスタを使い、漏洩リスクを受容できないならデプロイしないでください。
- namespace 作成と policy 作成はトランザクションではありません。途中で失敗した場合、画面にエラーが表示されます。残存 namespace と適用済み policy を確認して手動復旧してください。
- 削除は namespace 内のワークロード・Secret・PVC 等を削除し得ます。PV の reclaim policy 次第でデータが失われる可能性があります。外部 DB VM や S3 は削除しません。バックアップ・保持を確認してください。
- 既存 Git 管理テナントは画面に表示されますが、画面から削除できません。直接操作と GitOps で同じリソースを同時管理しないでください。

## 試し方

1. Docker が動く環境で、`admin` を作業ディレクトリにして以下を実行します。PHP・Composer のホストへのインストールは不要です。WSL 上の Docker を利用する場合は WSL 側から実行してください。

   ```sh
   docker build --target test -t tenant-admin-test .
   docker run --rm tenant-admin-test
   docker build --target runtime -t tenant-admin:sample .
   ```

2. ビルドした runtime image を実験クラスタが取得可能な registry に push します。[admin.ts](../cdk8s/src/resources/admin.ts) の placeholder image を変更し、[README の手順](../README.md#cdk8s-の生成と動作検証)で再生成します。
3. 実験クラスタに `kubectl create namespace platform-admin` で namespace を作り、`tenant-admin-auth` Secret を作成します。Secret キーは `username`、`password-hash`（PHP の `password_hash` による bcrypt）、`app-key`（Laravel の `base64:` 付き 32 バイト鍵）です。値はファイルなどから渡し、コマンド履歴や Git に残しません。その後 `kubectl apply -f kubernetes\dist\admin` で生成済み manifest を適用します。
4. Deployment の Ready を確認し、`kubectl -n platform-admin port-forward service/tenant-admin 8000:8000` で `http://127.0.0.1:8000` に接続します。port-forward はクラスタ API 権限が必要です。CNI によって接続元や制御が異なるため、deny-inbound policy の挙動も確認してください。
5. 書き込みを試す場合のみ TypeScript 定義の `PLATFORM_WRITES_ENABLED` を `true` にして再生成・再適用します。画面で `tenant-` から始まる名前を指定します。削除にはテナント名の再入力が必要です。

Laravel 付属の開発用サーバーと Basic 認証は本番向けの管理サービスではありません。複数運用者、SSO、監査、GitOps と連動したプロビジョニングには別設計が必要です。

ローカルで `docker compose up --build` する場合は `.env.example` を `.env` にコピーし、認証・`APP_KEY` を設定してください。localhost のみで公開します。ただし API 接続先は Kubernetes 内の ServiceAccount を前提としているため、Compose 単体では `/up` 以外の実際のテナント操作はできません。
