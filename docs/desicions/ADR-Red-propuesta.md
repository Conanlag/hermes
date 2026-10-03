# ADR: Comunicación de Hermes entre computadoras mediante red local

## Contexto

Actualmente, Hermes ejecuta los Jobs de manera local en la misma computadora donde se encuentra instalado.

Como evolución futura del proyecto, se propone permitir que una computadora pueda enviar Jobs a otra computadora conectada a la misma red local.

En este escenario, una computadora actuará como **cliente**, encargada de solicitar la ejecución de un Job, mientras que otra ejecutará Hermes como **servidor** y será responsable de recibir y ejecutar dicho Job.

Esta funcionalidad todavía no será implementada y se documenta como una propuesta para una etapa posterior del proyecto.

## Decisión

Se propone implementar una comunicación directa entre dos computadoras mediante una **red local (LAN)**.

La computadora cliente enviará una solicitud a la computadora que ejecuta Hermes como servidor.

La arquitectura propuesta será:

```text
┌─────────────────────┐
│   Computadora A     │
│      Cliente        │
│                     │
│  Solicita un Job    │
└──────────┬──────────┘
           │
           │ Red local (LAN)
           │
           ▼
┌─────────────────────┐
│   Computadora B     │
│      Hermes         │
│      Servidor       │
│                     │
│  Recibe el Job      │
│  Ejecuta el Job     │
│  Actualiza estado   │
└─────────────────────┘
```

La computadora que ejecuta Hermes será responsable de:

* Recibir el Job enviado por la computadora cliente.
* Asignar el `job_id`.
* Agregar el Job a la cola.
* Ejecutar el proceso.
* Actualizar su estado.
* Mantener la información persistida del Job.
* Responder al cliente con la información correspondiente.

La computadora cliente será responsable de enviar la solicitud y, posteriormente, consultar el estado del Job.

La comunicación se realizará dentro de la misma red local. El protocolo de comunicación, puerto, formato de mensajes y mecanismo de autenticación serán definidos cuando esta funcionalidad sea implementada.

## Justificación

| Justificación     |                                                                                                                                                                                                                        |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Alternativas      | Mantener Hermes exclusivamente local o utilizar una comunicación a través de Internet.                                                                                                                                 |
| Consecuencias     | Una computadora podrá solicitar la ejecución de Jobs en otra computadora conectada a la misma red local, permitiendo evolucionar Hermes de un sistema exclusivamente local a un sistema distribuido entre dos equipos. |
| Riesgos           | La computadora servidor deberá permanecer disponible y accesible dentro de la red local. También será necesario controlar qué equipos pueden enviar Jobs para evitar solicitudes no autorizadas.                       |
| Evidencia técnica | Actualmente Hermes ejecuta los Jobs de manera local. Esta comunicación entre computadoras se plantea como una funcionalidad futura y todavía no forma parte de la implementación actual.                               |
