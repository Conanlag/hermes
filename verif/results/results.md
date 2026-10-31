# Evidencias de ejecuciones de prueba

| Caso | Req ID | Descripción | Resultado | Evidencia |
|:---|:---|:---|:---|:---|
| TC-021 | RF-30 | Cancelación normal de un proceso que ignora SIGTERM y escalamiento forzoso después del periodo de gracia de 5 segundos | PASS | `verif/results/tc021.log` |
| TC-024 | RNF-33 | Liberación de recursos tras 100 Jobs `true`; no se estresó el ciclo de vida de sockets | PASS parcial (2026-10-30) | `verif/results/results_TC-024.md` |
| TC-025 | RF-05 | Configuración y límite de trabajos simultáneos | PASS (2026-10-30) | Salida de `verif/scripts/TC-025.sh` |
