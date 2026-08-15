# Contributing to InMyFace

IssueやPull Requestを歓迎します。予定名、カレンダー名、会議URL、ローカルパスなどの個人情報は、公開前に必ずサンプルへ置き換えてください。

## 開発の流れ

1. Issueを確認するか、新しいIssueで変更内容を相談します。
2. `main`から作業ブランチを作成します。
3. Xcodeで変更し、Release構成をビルドします。
4. 変更をpushしてPull Requestを作成します。
5. CIの成功と未解決コメントがないことを確認してマージします。

`main`への直接pushとforce-pushは禁止されています。

## ローカルでの確認

```sh
xcodebuild \
  -project InMyFace.xcodeproj \
  -scheme InMyFace \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

UIを変更した場合は、明るい背景と暗い背景の両方で通知画面を確認してください。Esc、Dismiss、Snooze、Join meetingも確認します。

## セキュリティとプライバシー

- 認証情報、署名証明書、Provisioning Profileをcommitしない
- 実際の予定や会議URLをテストデータ・画像へ含めない
- スクリーンショットのGPS、端末名、ICCプロファイルなどを除去する
- 脆弱性は公開Issueへ書かず、[Security Advisory](https://github.com/knishi-outcome/InMyFace/security/advisories/new)から報告する
