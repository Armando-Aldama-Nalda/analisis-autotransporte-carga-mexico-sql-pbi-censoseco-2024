--PROYECTO ANÁLISIS DEL SECTOR AUTOTRANSPORTE--

--Documentación de códigos SQL definitivos

--1. Verificar carga original de la tabla cruda

--Sirve para confirmar cuántas filas entraron desde el CSV.

USE ArmandoDataLab;
GO

SELECT COUNT(*) AS filas_originales
FROM dbo.tr_ce_nac_2024;

--Resultado: 7371.

--2. Crear vista limpia de la tabla base Esta vista elimina:

--la fila de encabezados importada como dato

--filas de totales sin código válido

--Y conserva las filas útiles para análisis.

CREATE OR ALTER VIEW dbo.vw_tr_ce_nac_2024_limpia AS

SELECT

    column1  AS E03,
    column2  AS E04,
    column3  AS SECTOR,
    column4  AS SUBSECTOR,
    column5  AS RAMA,
    column6  AS SUBRAMA,
    column7  AS CLASE,

    column8  AS ID_ESTRATO,
    column9  AS CODIGO,

    column10 AS UE,

    column11 AS H001A,
    column12 AS H000A,
    column13 AS H010A,
    column14 AS H020A,
    column17 AS K000A,
    column16 AS J000A,

    column19 AS A111A,
    column20 AS A121A,
    column21 AS A131A,

    column22 AS A211A,
    column25 AS Q000A,
    column28 AS A800A,

    column54 AS H203A,

    column82 AS K042A,
    column90 AS K820A,

    column105 AS Q030A

FROM dbo.tr_ce_nac_2024

WHERE
    (column1 IS NULL OR column1 <> 'E03')
    AND column9 IS NOT NULL;


--Para validar:

SELECT COUNT(*) AS filas_limpias
FROM dbo.vw_tr_ce_nac_2024_limpia;

--Resultado: 7355.
-- también: 
SELECT TOP 10
    A211A AS inversion_total_MDP,
    A800A AS ingresos_totales_MDP,
    H203A AS personal_administrativo,
    K000A AS gastos_bienes_servicios_MDP,
    K042A AS consumo_combustibles_energeticos_MDP,
    K820A AS servicios_comunicacion_MDP,
    Q000A AS activos_fijos_totales_MDP,
    Q030A AS equipo_transporte_MDP,
    J000A AS remuneraciones_totales_MDP
FROM dbo.vw_tr_ce_nac_2024_limpia;


--3. Aislar el sector de autotransporte de carga

CREATE OR ALTER VIEW dbo.vw_autotransporte_484 AS

SELECT *
FROM dbo.vw_tr_ce_nac_2024_limpia
WHERE CODIGO LIKE '484%'
AND ID_ESTRATO IS NOT NULL;

--Validación: 
SELECT COUNT(*) AS filas_autotransporte
FROM dbo.vw_autotransporte_484;


--Usamos CODIGO LIKE '484%' porque el análisis está centrado en autotransporte de carga.
--tenemos 82 filas 
--https://www.inegi.org.mx/scian/
--Además excluimos los totales por estrato con ID_ESTRATO IS NOT NULL.Ya que cuando la celda estaba vacía, 
--se observó que eran los totales de la suma de lo 4 estratos o del estrato único en caso 99


--4. Estructura del sector por estrato
--Este código da la composición básica del sector por tamaño de empresa.

SELECT
    ID_ESTRATO,
    SUM(TRY_CAST(UE AS FLOAT)) AS empresas,
    SUM(TRY_CAST(H001A AS FLOAT)) AS empleo,
    SUM(TRY_CAST(A111A AS FLOAT)) AS produccion
FROM dbo.vw_autotransporte_484
GROUP BY ID_ESTRATO
ORDER BY ID_ESTRATO;

--Estos nos dice cuántas empresas hay por estrato; cuánto empleo concentra cada estrato; cuánta producción concentra cada estrato



--5. Tabla de quintiles

CREATE OR ALTER VIEW dbo.vw_base_quintiles_prod_empresa_484 AS
WITH base AS (
    SELECT
        CODIGO,
        ID_ESTRATO,

        TRY_CAST(UE AS FLOAT) AS UE,
        TRY_CAST(H001A AS FLOAT) AS empleo,

        TRY_CAST(A111A AS FLOAT) AS produccion_MDP,
        TRY_CAST(A800A AS FLOAT) AS ingresos_MDP,
        TRY_CAST(K000A AS FLOAT) AS gastos_MDP,
        TRY_CAST(A211A AS FLOAT) AS inversion_MDP,
        TRY_CAST(Q000A AS FLOAT) AS activos_MDP,
        TRY_CAST(Q030A AS FLOAT) AS equipo_transporte_MDP,
        TRY_CAST(K042A AS FLOAT) AS combustibles_MDP,
        TRY_CAST(K820A AS FLOAT) AS comunicaciones_MDP,
        TRY_CAST(J000A AS FLOAT) AS remuneraciones_mdp,

        TRY_CAST(A111A AS FLOAT) / NULLIF(TRY_CAST(UE AS FLOAT), 0) AS prod_empresa_MDP
    FROM dbo.vw_autotransporte_484
    WHERE TRY_CAST(UE AS FLOAT) IS NOT NULL
      AND TRY_CAST(UE AS FLOAT) > 0
      AND TRY_CAST(H001A AS FLOAT) IS NOT NULL
      AND TRY_CAST(A111A AS FLOAT) IS NOT NULL
),
totales AS (
    SELECT SUM(UE) AS total_ue
    FROM base
),
orden AS (
    SELECT
        b.*,
        t.total_ue,
        SUM(b.UE) OVER (
            ORDER BY b.prod_empresa_MDP, b.ID_ESTRATO, b.CODIGO
            ROWS UNBOUNDED PRECEDING
        ) AS ue_acum
    FROM base b
    CROSS JOIN totales t
)
SELECT
    CODIGO,
    ID_ESTRATO,
    UE,
    empleo,
    produccion_MDP,
    ingresos_MDP,
    gastos_MDP,
    inversion_MDP,
    activos_MDP,
    equipo_transporte_MDP,
    combustibles_MDP,
    comunicaciones_MDP,
    prod_empresa_MDP,
    remuneraciones_mdp,

    CASE
        WHEN total_ue IS NULL OR total_ue = 0 THEN NULL
        WHEN ue_acum <= 0.2 * total_ue THEN 1
        WHEN ue_acum <= 0.4 * total_ue THEN 2
        WHEN ue_acum <= 0.6 * total_ue THEN 3
        WHEN ue_acum <= 0.8 * total_ue THEN 4
        ELSE 5
    END AS quintil_prod_empresa
FROM orden;
GO

--Validación rápida (cada quintil debe tener ~20% de empresas)
SELECT
    quintil_prod_empresa,
    SUM(UE) AS empresas,
    SUM(UE) * 1.0 / SUM(SUM(UE)) OVER() AS pct_empresas
FROM dbo.vw_base_quintiles_prod_empresa_484
GROUP BY quintil_prod_empresa
ORDER BY quintil_prod_empresa;
GO

--6. Promedios por quintil
CREATE OR ALTER VIEW dbo.vw_quintil_promedios_484 AS
SELECT
    quintil_prod_empresa,
    SUM(UE) AS empresas,

    SUM(empleo) / NULLIF(SUM(UE), 0) AS empleo_promedio,
    SUM(produccion_MDP) / NULLIF(SUM(UE), 0) AS produccion_promedio_MDP,
    SUM(ingresos_MDP) / NULLIF(SUM(UE), 0) AS ingresos_promedio_MDP,
    SUM(gastos_MDP) / NULLIF(SUM(UE), 0) AS gastos_promedio_MDP,
    SUM(inversion_MDP) / NULLIF(SUM(UE), 0) AS inversion_promedio_MDP,
    SUM(activos_MDP) / NULLIF(SUM(UE), 0) AS activos_promedio_MDP,
    SUM(equipo_transporte_MDP) / NULLIF(SUM(UE), 0) AS equipo_transporte_promedio_MDP,
    SUM(combustibles_MDP) / NULLIF(SUM(UE), 0) AS combustibles_promedio_MDP,
    SUM(comunicaciones_MDP) / NULLIF(SUM(UE), 0) AS comunicaciones_promedio_MDP,
    SUM(remuneraciones_mdp) / NULLIF(SUM(UE), 0) AS remuneraciones_promedio_MDP

FROM dbo.vw_base_quintiles_prod_empresa_484
GROUP BY quintil_prod_empresa;
GO

--Visualización:

SELECT *
FROM dbo.vw_quintil_promedios_484
ORDER BY quintil_prod_empresa;
GO

--7. Cruce estrato × quintil en valores absolutos

--Esta tabla muestra cuántas empresas de cada estrato caen en cada quintil.

CREATE OR ALTER VIEW dbo.vw_estrato_quintil_abs_484 AS
SELECT
    ID_ESTRATO,
    quintil_prod_empresa,
    SUM(UE) AS empresas
FROM dbo.vw_base_quintiles_prod_empresa_484
GROUP BY
    ID_ESTRATO,
    quintil_prod_empresa;

-- Vista de tabla:
SELECT
    ID_ESTRATO,
    SUM(CASE WHEN quintil_prod_empresa = 1 THEN UE ELSE 0 END) AS Q1,
    SUM(CASE WHEN quintil_prod_empresa = 2 THEN UE ELSE 0 END) AS Q2,
    SUM(CASE WHEN quintil_prod_empresa = 3 THEN UE ELSE 0 END) AS Q3,
    SUM(CASE WHEN quintil_prod_empresa = 4 THEN UE ELSE 0 END) AS Q4,
    SUM(CASE WHEN quintil_prod_empresa = 5 THEN UE ELSE 0 END) AS Q5,
    SUM(UE) AS total_empresas
FROM dbo.vw_base_quintiles_prod_empresa_484
GROUP BY ID_ESTRATO
ORDER BY ID_ESTRATO;
    
 
 --8. Cruce estrato × quintil en porcentajes por quintil


CREATE OR ALTER VIEW dbo.vw_estrato_quintil_pct_por_quintil_484 AS
WITH abs AS (
    SELECT
        ID_ESTRATO,
        quintil_prod_empresa,
        SUM(UE) AS empresas
    FROM dbo.vw_base_quintiles_prod_empresa_484
    GROUP BY
        ID_ESTRATO,
        quintil_prod_empresa
)
SELECT
    ID_ESTRATO,
    quintil_prod_empresa,
    empresas,
    empresas * 1.0 / NULLIF(SUM(empresas) OVER (PARTITION BY quintil_prod_empresa), 0) AS pct_en_quintil
FROM abs;
GO

--validacion 
SELECT *
FROM dbo.vw_estrato_quintil_pct_por_quintil_484
ORDER BY quintil_prod_empresa, ID_ESTRATO;
GO

--9. Versión “matriz” (Consulta auxiliar)
WITH abs AS (
    SELECT
        ID_ESTRATO,
        quintil_prod_empresa,
        SUM(UE) AS empresas
    FROM dbo.vw_base_quintiles_prod_empresa_484
    GROUP BY ID_ESTRATO, quintil_prod_empresa
),
pct AS (
    SELECT
        ID_ESTRATO,
        quintil_prod_empresa,
        empresas * 1.0 / NULLIF(SUM(empresas) OVER (PARTITION BY quintil_prod_empresa), 0) AS pct_en_quintil
    FROM abs
)
SELECT
    ID_ESTRATO,
    SUM(CASE WHEN quintil_prod_empresa = 1 THEN pct_en_quintil ELSE 0 END) AS pct_en_Q1,
    SUM(CASE WHEN quintil_prod_empresa = 2 THEN pct_en_quintil ELSE 0 END) AS pct_en_Q2,
    SUM(CASE WHEN quintil_prod_empresa = 3 THEN pct_en_quintil ELSE 0 END) AS pct_en_Q3,
    SUM(CASE WHEN quintil_prod_empresa = 4 THEN pct_en_quintil ELSE 0 END) AS pct_en_Q4,
    SUM(CASE WHEN quintil_prod_empresa = 5 THEN pct_en_quintil ELSE 0 END) AS pct_en_Q5
FROM pct
GROUP BY ID_ESTRATO
ORDER BY ID_ESTRATO;
GO

--Validación rápida (cada quintil debe dar 1.0)
WITH abs AS (
    SELECT quintil_prod_empresa, SUM(UE) AS empresas
    FROM dbo.vw_base_quintiles_prod_empresa_484
    GROUP BY quintil_prod_empresa
)
SELECT quintil_prod_empresa, empresas
FROM abs
ORDER BY quintil_prod_empresa;
GO

--10. Rangos de Quintiles: 

CREATE OR ALTER VIEW dbo.vw_quintil_rangos_prod_empresa_484 AS
SELECT
    quintil_prod_empresa,
    MIN(prod_empresa_MDP) AS prod_empresa_min_MDP,
    MAX(prod_empresa_MDP) AS prod_empresa_max_MDP
FROM dbo.vw_base_quintiles_prod_empresa_484
GROUP BY quintil_prod_empresa;

-- 11. “Porcentajes por estrato” (cada estrato suma 100%) para contrastar ambas lecturas.

CREATE OR ALTER VIEW dbo.vw_estrato_quintil_pct_por_estrato_484 AS
WITH abs AS (
    SELECT
        ID_ESTRATO,
        quintil_prod_empresa,
        SUM(UE) AS empresas
    FROM dbo.vw_base_quintiles_prod_empresa_484
    GROUP BY
        ID_ESTRATO,
        quintil_prod_empresa
),
pct AS (
    SELECT
        ID_ESTRATO,
        quintil_prod_empresa,
        empresas * 1.0 / NULLIF(SUM(empresas) OVER (PARTITION BY ID_ESTRATO), 0) AS pct_en_estrato
    FROM abs
)
SELECT
    ID_ESTRATO,
    quintil_prod_empresa,
    pct_en_estrato
FROM pct;
GO

--12. Tabla PROMEDIOS POR ESTRATO
CREATE OR ALTER VIEW dbo.vw_estrato_promedios_484 AS
WITH base AS (
    SELECT
        ID_ESTRATO,
        TRY_CAST(UE AS FLOAT) AS UE,
        TRY_CAST(H001A AS FLOAT) AS empleo,
        TRY_CAST(A111A AS FLOAT) AS produccion_MDP,
        TRY_CAST(A800A AS FLOAT) AS ingresos_MDP,
        TRY_CAST(K000A AS FLOAT) AS gastos_MDP,
        TRY_CAST(A211A AS FLOAT) AS inversion_MDP,
        TRY_CAST(Q000A AS FLOAT) AS activos_MDP,
        TRY_CAST(Q030A AS FLOAT) AS equipo_transporte_MDP,
        TRY_CAST(K042A AS FLOAT) AS combustibles_MDP,
        TRY_CAST(K820A AS FLOAT) AS comunicaciones_MDP
    FROM dbo.vw_autotransporte_484
    WHERE TRY_CAST(UE AS FLOAT) > 0
)
SELECT
    ID_ESTRATO,
    SUM(UE) AS empresas,

    SUM(empleo) / SUM(UE) AS empleo_promedio,
    SUM(produccion_MDP) / SUM(UE) AS produccion_promedio_MDP,
    SUM(ingresos_MDP) / SUM(UE) AS ingresos_promedio_MDP,
    SUM(gastos_MDP) / SUM(UE) AS gastos_promedio_MDP,
    SUM(inversion_MDP) / SUM(UE) AS inversion_promedio_MDP,
    SUM(activos_MDP) / SUM(UE) AS activos_promedio_MDP,
    SUM(equipo_transporte_MDP) / SUM(UE) AS equipo_transporte_promedio_MDP,
    SUM(combustibles_MDP) / SUM(UE) AS combustibles_promedio_MDP,
    SUM(comunicaciones_MDP) / SUM(UE) AS comunicaciones_promedio_MDP

FROM base
GROUP BY ID_ESTRATO;
GO

--13. TOTALES X ESTRATO
CREATE OR ALTER VIEW dbo.vw_estrato_totales_484 AS
SELECT
    ID_ESTRATO,

    SUM(TRY_CAST(UE AS FLOAT)) AS empresas,
    SUM(TRY_CAST(H001A AS FLOAT)) AS empleo,

    SUM(TRY_CAST(A111A AS FLOAT)) AS produccion_total_MDP,
    SUM(TRY_CAST(A800A AS FLOAT)) AS ingresos_total_MDP,
    SUM(TRY_CAST(K000A AS FLOAT)) AS gastos_total_MDP,
    SUM(TRY_CAST(A211A AS FLOAT)) AS inversion_total_MDP,
    SUM(TRY_CAST(Q000A AS FLOAT)) AS activos_total_MDP,
    SUM(TRY_CAST(Q030A AS FLOAT)) AS equipo_transporte_total_MDP,
    SUM(TRY_CAST(K042A AS FLOAT)) AS combustibles_total_MDP,
    SUM(TRY_CAST(K820A AS FLOAT)) AS comunicaciones_total_MDP

FROM dbo.vw_autotransporte_484
GROUP BY ID_ESTRATO;
GO

SELECT *
FROM dbo.vw_estrato_totales_484
ORDER BY ID_ESTRATO;


--14 TOTALES X QUINTIL
CREATE OR ALTER VIEW dbo.vw_quintil_totales_484 AS
SELECT
    quintil_prod_empresa,

    SUM(UE) AS empresas,
    SUM(empleo) AS empleo,

    SUM(produccion_MDP) AS produccion_total_MDP,
    SUM(ingresos_MDP) AS ingresos_total_MDP,
    SUM(gastos_MDP) AS gastos_total_MDP,
    SUM(inversion_MDP) AS inversion_total_MDP,
    SUM(activos_MDP) AS activos_total_MDP,
    SUM(equipo_transporte_MDP) AS equipo_transporte_total_MDP,
    SUM(combustibles_MDP) AS combustibles_total_MDP,
    SUM(comunicaciones_MDP) AS comunicaciones_total_MDP

FROM dbo.vw_base_quintiles_prod_empresa_484
GROUP BY quintil_prod_empresa;
GO



--13. Validaciones: 
SELECT * 
FROM dbo.vw_base_quintiles_prod_empresa_484
ORDER BY quintil_prod_empresa, ID_ESTRATO;

SELECT *
FROM dbo.vw_estrato_totales_484
ORDER BY ID_ESTRATO;

SELECT *
FROM dbo.vw_estrato_promedios_484
ORDER BY ID_ESTRATO;
GO

SELECT *
FROM dbo.vw_quintil_promedios_484
ORDER BY quintil_prod_empresa;
GO

SELECT *
FROM dbo.vw_quintil_rangos_prod_empresa_484
ORDER BY quintil_prod_empresa;
GO

SELECT * 
FROM dbo.vw_estrato_quintil_abs_484
ORDER BY ID_ESTRATO, quintil_prod_empresa;

SELECT * 
FROM dbo.vw_estrato_quintil_pct_por_quintil_484
ORDER BY quintil_prod_empresa, ID_ESTRATO;

SELECT * 
FROM dbo.vw_estrato_quintil_pct_por_estrato_484
ORDER BY ID_ESTRATO, quintil_prod_empresa;

SELECT quintil_prod_empresa, SUM(UE) AS empresas
FROM dbo.vw_base_quintiles_prod_empresa_484
GROUP BY quintil_prod_empresa
ORDER BY quintil_prod_empresa;
GO