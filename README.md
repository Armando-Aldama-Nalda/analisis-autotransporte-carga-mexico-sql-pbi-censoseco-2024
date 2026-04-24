Análisis de la Productividad y Eficiencia: Sector Autotransporte de Carga (México, 2024)


I. Introducción

El autotransporte de carga es uno de los sectore clave para el crecimiento sostenido de economía mexicana, representando aproximadamente 4% del PIB nacional de acuerdo con datos de 2025. Sin embargo, es un sector fragmentado donde conviven desde micro-empresas familiares hasta grandes consorcios logísticos.

Este proyecto nace con el objetivo de realizar un análisis de los principales indicadores de eficiencia económica del sector. Mediante el procesamiento de los datos de los Censos Económicos 2024 (INEGI), diseñé una metodología para segmentar a más de 30,000 unidades económicas y entender quiénes son realmente productivos y dónde se concentran sus costos.

II. Metodología: 

-Para este análisis, construí un ecosistema de datos que garantiza limpieza y escalabilidad:

  -SQL Server: Procesamiento ETL, ingeniería de variables y lógica de segmentación avanzada.

  -Power BI: Visualización interactiva y creación de KPIs financieros.

  -En lugar de comparar empresas por número de empleados, las clasifiqué por el valor de la producción anual de las  empresas. Usé Window Functions (SUM() OVER) para dividir el sector en 5 grupos iguales (quintiles).

III. Desafíos Técnicos y Soluciones1. 

Limpieza de Datos (Data Wrangling). Los datos crudos del censo venían con estructuras jerárquicas y filas de totales que ensuciaban el análisis. Implementé Vistas en SQL para:

  -Eliminar ruido y filas de encabezados importadas.

  -Estandarizar valores nulos y tipos de datos mediante TRY_CAST.

  -Aislar el código SCIAN 484 (Autotransporte de carga).

IV. Insights

-El Quintil 5 (el 20% más productivo) no siempre son las empresas más grandes, sino las que mejor optimizan sus activos.

-El "Dolor" del Combustible: El análisis reveló que el gasto en combustibles absorbe el 25.2% de los ingresos totales del sector, siendo el principal cuello de botella para el crecimiento.

-Oportunidad de Inversión: Identifiqué que los Quintiles 3 y 4 son el "motor silencioso": generan una producción sólida (20-25 MDP anuales) y muestran una alta tasa de reinversión en equipo de transporte.

-Concentración de Activos: 77% de las empresas grandes (Estrato 4) logran situarse en el Quintil más alto de productividad, confirmando que la economía de escala es vital en este rubro.

V. Visualización de KPIs

<img width="1308" height="805" alt="KPIs_2" src="https://github.com/user-attachments/assets/383e5460-695d-41ee-9cfe-0a9bc6f8a7a2" />

VI. Contenido del Repositorio

scripts_sql/: Contiene el código para la creación de vistas y lógica de quintiles.

visualizaciones/: Capturas de pantalla del reporte final.

Data/:Base de datos cruda del censo económico realizado por el INEGI en 2024. 

Fuente: https://www.inegi.org.mx/programas/ce/2024/#datos_abiertos

Armando Aldama-Nalda
Economista especializado en el análisis de datos del sector público mexicano. Actualmente en transición hacia el Análisis de Datos para su uso en proyectos relacoinados con Inteligencia Artificial. Mi enfoque combina el rigor estadístico con la capacidad de transformar datos técnicos en decisiones estratégicas de negocio.
Mi contacto es fco.aldama@gmail.com

