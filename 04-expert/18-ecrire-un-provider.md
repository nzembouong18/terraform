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

## Exercices
1. Lancez `terraform providers schema -json | jq '.provider_schemas | keys'` dans un lab : explorez le schéma de `random_pet`.
2. Activez `TF_LOG=DEBUG` sur un `apply` du module 01 : repérez les appels gRPC `PlanResourceChange`/`ApplyResourceChange`.
3. Clonez le scaffolding-framework, ajoutez une ressource `note` en mémoire, testez-la avec `dev_overrides`.
4. Lisez le code de `terraform-provider-random` (simple) : comment `random_pet` implémente-t-il `Read` (no-op) ?
5. Défi : ajoutez `ImportState` à votre ressource et écrivez le test d'acceptation correspondant.
