# 18 — Écrire un provider (introduction)

Vous n'en écrirez pas souvent, mais comprendre l'architecture rend expert pour le diagnostic.

## Architecture
```
terraform (core)  ⇄  gRPC (protocole des plugins)  ⇄  provider (binaire Go)  ⇄  API distante
```
- Le **core** lit la config, construit le graphe, calcule les diffs, gère le state.
- Le **provider** expose : un **schéma** (ressources, data sources, fonctions) et les opérations **CRUD** (`Create/Read/Update/Delete`), plus `ImportState`, `ValidateConfig`, `ModifyPlan`.
- Deux SDK : **Plugin Framework** (recommandé, nouveau code) et SDKv2 (legacy).

## Cycle de vie d'un `apply` (côté provider)
1. `ValidateResourceConfig` → 2. `PlanResourceChange` (calcul des valeurs « known after apply », `RequiresReplace`) → 3. `ApplyResourceChange` (Create/Update/Delete) → 4. `ReadResource` lors des refresh.

## Squelette (Plugin Framework)
```go
func (r *noteResource) Schema(_ context.Context, _ resource.SchemaRequest, resp *resource.SchemaResponse) {
    resp.Schema = schema.Schema{
        Attributes: map[string]schema.Attribute{
            "id":      schema.StringAttribute{Computed: true},
            "contenu": schema.StringAttribute{Required: true},
        },
    }
}
func (r *noteResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
    var plan noteModel
    resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
    // appeler l'API, remplir plan.ID
    resp.Diagnostics.Append(resp.State.Set(ctx, plan)...)
}
```
Point de départ officiel : dépôt modèle `terraform-provider-scaffolding-framework` (HashiCorp).

## Tests
- Unitaires Go classiques.
- **Tests d'acceptation** (`resource.Test` avec `TF_ACC=1`) : exécutent un vrai Terraform contre l'API ; vérifient create/update/import/destroy.

## Débogage
```bash
export TF_LOG=TRACE                     # TRACE, DEBUG, INFO, WARN, ERROR
export TF_LOG_PATH=./tf.log
export TF_LOG_PROVIDER=DEBUG            # seulement les logs des providers
```
`terraform providers`, `terraform providers schema -json` (inspecter le schéma), `terraform console`.

## Développement local
Dans `~/.terraformrc` :
```hcl
provider_installation {
  dev_overrides { "mon-org/mon-provider" = "/chemin/vers/bin" }
  direct {}
}
```

## Comprendre en profondeur

### Le protocole de plugin
Terraform lance le provider comme un **processus enfant** et dialogue avec lui en **gRPC** sur un socket local (protocole `tfplugin6`, anciennement 5). À l'ouverture, la poignée de main négocie la version du protocole et un jeton. Le provider reste actif pendant toute l'opération, puis est arrêté. Conséquences : un provider est un binaire autonome (Go le plus souvent), les erreurs de provider remontent comme des diagnostics, un crash apparaît comme *« The plugin encountered an error »* avec la trace dans les logs `TRACE`.

### Les types d'objets exposés par un provider
| Élément | Rôle | Opérations |
|---------|------|------------|
| **Resource** | objet géré | Create / Read / Update / Delete / ImportState |
| **Data source** | lecture seule | Read |
| **Function** (≥ 1.8) | calcul pur | Run |
| **Ephemeral resource** (≥ 1.10) | valeur temporaire non stockée | Open / Renew / Close |
| **Provider config** | authentification, URL | Configure |

### Le schéma : le contrat avec le cœur
Chaque attribut déclare : **Required** (obligatoire), **Optional**, **Computed** (calculé par le provider) ou une combinaison (*Optional + Computed* : l'utilisateur peut le fixer, sinon le provider choisit), **Sensitive**, **WriteOnly**, ainsi que des *plan modifiers* (`RequiresReplace`, `UseStateForUnknown`) et des *validators*. Le cœur utilise ce schéma pour :
- valider la configuration **avant** tout appel à l'API ;
- décider si une différence est une **modification en place** ou un **remplacement** ;
- masquer les valeurs sensibles.

Un schéma mal pensé produit des plans bruyants (« known after apply » partout) ou des remplacements inutiles. Les plus grosses sources de bugs dans les providers viennent d'un décalage entre **ce que l'utilisateur écrit** et **ce que l'API renvoie** (normalisation : casse, ordre des listes, valeurs par défaut).

### Les règles de cohérence que le cœur impose
1. Après `apply`, toute valeur *inconnue* du plan doit être devenue **connue**.
2. Une valeur *connue* au plan ne doit **pas changer** à l'apply (sinon *« Provider produced inconsistent result after apply »*).
3. Après un `Read`, l'état doit refléter la réalité ; l'absence de l'objet doit supprimer la ressource du state.
4. L'`ImportState` doit permettre à un `plan` ultérieur de ne rien changer (idempotence).
Ces messages d'erreur sont des **bogues du provider**, pas de l'utilisateur ; ils se signalent au dépôt du provider.

### Écrire une ressource : checklist
- [ ] Schéma complet, `description` pour la documentation générée (`tfplugindocs`).
- [ ] `Create` renseigne **tous** les attributs `Computed`.
- [ ] `Read` gère *not found* (retirer du state) et normalise les valeurs.
- [ ] `Update` ne ré-applique que ce qui a changé ; attributs immuables → `RequiresReplace`.
- [ ] `Delete` est idempotent (déjà supprimé = succès).
- [ ] `ImportState` retrouve toutes les informations depuis l'identifiant.
- [ ] Gestion des **timeouts** et des **retries** sur les erreurs transitoires (429, 5xx).
- [ ] Attributs secrets `Sensitive` (et `WriteOnly` si possible).
- [ ] Tests d'acceptation couvrant create / update / import / destroy / disappears.

### Tests d'acceptation en pratique
```go
func TestAccNote_basic(t *testing.T) {
    resource.Test(t, resource.TestCase{
        ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
        Steps: []resource.TestStep{
            {   // 1. création + vérifications
                Config: `resource "demo_note" "n" { contenu = "bonjour" }`,
                Check:  resource.TestCheckResourceAttr("demo_note.n", "contenu", "bonjour"),
            },
            {   // 2. import : l'état importé doit être identique
                ResourceName:      "demo_note.n",
                ImportState:       true,
                ImportStateVerify: true,
            },
            {   // 3. mise à jour
                Config: `resource "demo_note" "n" { contenu = "salut" }`,
                Check:  resource.TestCheckResourceAttr("demo_note.n", "contenu", "salut"),
            },
        },
    })
}
```
À chaque étape, le framework exécute `apply` puis un `plan` qui doit être **vide** : c'est ce qui révèle les attributs non normalisés.

### Distribution
1. Dépôt `terraform-provider-<nom>` ; releases avec **GoReleaser** (binaires multi-plateformes, sommes de contrôle).
2. **Signature GPG** des sommes de contrôle ; clé publique enregistrée dans le registry.
3. Publication sur le **Terraform Registry** (ou OpenTofu Registry) ou dans un registry privé / miroir interne.
4. Documentation générée par `tfplugindocs` à partir du schéma et d'exemples.
5. Versionnement SemVer rigoureux : changer un attribut en `RequiresReplace` est cassant.

### Alternatives à l'écriture d'un provider
| Besoin | Option | Compromis |
|--------|--------|-----------|
| Appeler une API ponctuellement | `http` data source, `external` (script) | peu robuste, pas de cycle de vie |
| API REST générique | provider `restapi` / `mastercard/restapi` | configuration verbeuse |
| Ressource Kubernetes personnalisée | `kubernetes_manifest`, Crossplane | autre modèle |
| Générer un provider depuis une spec OpenAPI | `terraform-plugin-codegen-openapi` | point de départ à compléter |
| Logique complexe | module + providers existants, ou Pulumi/CDKTF | autre outillage |

Écrire un provider est un **investissement de maintenance** (compatibilité d'API, bugs, issues). Justifié quand une API est utilisée par beaucoup de monde ou de façon critique.

### Diagnostiquer un provider (côté utilisateur)
1. `TF_LOG_PROVIDER=DEBUG terraform plan` : voir les appels d'API et les erreurs.
2. Vérifier la **version** du provider (`terraform version`) et le changelog : bug connu ?
3. Reproduire avec un exemple minimal ; chercher l'issue dans le dépôt du provider.
4. Cas typiques : *« inconsistent result after apply »* (bug de provider), *« Provider configuration not present »* (provider supprimé de la config avant destruction), *« Invalid provider configuration »* (credentials manquants).

## Exercices
1. Lancez `terraform providers schema -json | jq '.provider_schemas | keys'` dans un lab : explorez le schéma de `random_pet`.
2. Activez `TF_LOG=DEBUG` sur un `apply` du module 01 : repérez les appels gRPC `PlanResourceChange`/`ApplyResourceChange`.
3. Clonez le scaffolding-framework, ajoutez une ressource `note` en mémoire, testez-la avec `dev_overrides`.
4. Lisez le code de `terraform-provider-random` (simple) : comment `random_pet` implémente-t-il `Read` (no-op) ?
5. Défi : ajoutez `ImportState` à votre ressource et écrivez le test d'acceptation correspondant.
