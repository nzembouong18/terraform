# 🧩 Modules complémentaires

À suivre après le niveau 3 (certains dès le niveau 2) : les mêmes concepts appliqués aux **autres clouds**, à **Kubernetes**, et un atelier de **débogage**.

| # | Module | Durée | Compte requis |
|---|--------|-------|---------------|
| 19 | [Azure](19-azure/README.md) | 2 h 30 | optionnel (`validate` + tests simulés sans compte) |
| 20 | [Google Cloud](20-gcp/README.md) | 2 h 30 | optionnel (idem) |
| 21 | [Kubernetes & Helm](21-kubernetes/README.md) | 2 h | cluster local `kind` (gratuit) |
| 22 | [Atelier de débogage](22-debug/README.md) | 2 h | **aucun** |

Les labs 19 et 20 sont validés en CI avec des **providers simulés** (`mock_provider`) ; un `apply` réel reste possible avec votre compte (pensez au `destroy`).
