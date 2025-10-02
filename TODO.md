# Repository Follow-Up Tasks

- [ ] Install `yamllint` in the local environment (ensure PyPI egress or configure a mirror/proxy).
- [ ] Rerun `yamllint -c .yamllint.yaml .` once installation succeeds and capture results.
- [ ] Authenticate `gh` CLI (`gh auth login -h github.com`) now that the token is invalid.
- [ ] Add GitHub remote (if not created): `git remote add origin git@github.com:diatonic-ai/k8s-local-config.git`.
- [ ] Push committed history to `main`: `git push -u origin main`.
- [ ] Consider removing the local `.venv/` if it will not be used going forward.
- [ ] Run `kubeconform` validation when accessible: `find k8s-manifests -name "*.yaml" -o -name "*.yml" | xargs kubeconform -summary -verbose`.
