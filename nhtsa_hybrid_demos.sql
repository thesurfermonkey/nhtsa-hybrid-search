USE NHTSA;
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET NOCOUNT ON;
GO
-- Coverage check
SELECT 'RecallVectors' AS tbl, COUNT(*) AS total, COUNT(Embedding) AS embedded FROM dbo.RecallVectors
UNION ALL SELECT 'ComplaintVectors', COUNT(*), COUNT(Embedding) FROM dbo.ComplaintVectors;
GO
-- DiskANN indexes
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name='vec_idx_recall' AND object_id=OBJECT_ID('dbo.RecallVectors'))
    DROP INDEX vec_idx_recall ON dbo.RecallVectors;
CREATE VECTOR INDEX vec_idx_recall ON dbo.RecallVectors(Embedding) WITH (METRIC='cosine', TYPE='diskann');
GO
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name='vec_idx_complaint' AND object_id=OBJECT_ID('dbo.ComplaintVectors'))
    DROP INDEX vec_idx_complaint ON dbo.ComplaintVectors;
CREATE VECTOR INDEX vec_idx_complaint ON dbo.ComplaintVectors(Embedding) WITH (METRIC='cosine', TYPE='diskann');
GO

/* HYBRID 1 — RECALLS: semantic "brakes fail / can't stop" + only Ford, model year >= 2018 */
DECLARE @q1 VECTOR(768) = CAST(AI_GENERATE_EMBEDDINGS(N'search_query: the brakes fail and the vehicle cannot stop safely' USE MODEL OllamaNomic) AS VECTOR(768));
PRINT '=== H1 Recalls about brake failure, FORD 2018+ ===';
SELECT TOP (8) CAST(r.distance AS decimal(9,4)) AS dist, rv.RecallNumber, LEFT(rv.Narrative,90) AS recall
FROM VECTOR_SEARCH(TABLE=dbo.RecallVectors AS rv, COLUMN=Embedding, SIMILAR_TO=@q1, METRIC='cosine', TOP_N=600) AS r
WHERE EXISTS (SELECT 1 FROM dbo.Recalls rc WHERE rc.RecallNumber=rv.RecallNumber AND rc.Make='FORD' AND rc.ModelYear>=2018)
ORDER BY r.distance;
GO

/* HYBRID 2 — EXPEDITION COMPLAINTS: semantic "transmission slips/jerks" + model years 2003-2010 */
DECLARE @q2 VECTOR(768) = CAST(AI_GENERATE_EMBEDDINGS(N'search_query: the transmission slips and shifts hard or jerks unexpectedly' USE MODEL OllamaNomic) AS VECTOR(768));
PRINT '=== H2 Expedition complaints about transmission, model year 2003-2010 ===';
SELECT TOP (8) CAST(r.distance AS decimal(9,4)) AS dist, c.ModelYear, c.Component, c.Crash, LEFT(c.Narrative,80) AS complaint
FROM VECTOR_SEARCH(TABLE=dbo.ComplaintVectors AS cv, COLUMN=Embedding, SIMILAR_TO=@q2, METRIC='cosine', TOP_N=400) AS r
JOIN dbo.Complaints c ON c.ComplaintRowID = cv.ComplaintRowID
WHERE c.ModelYear BETWEEN 2003 AND 2010
ORDER BY r.distance;
GO

/* HYBRID 3 — EXPEDITION COMPLAINTS: semantic "sudden fire" + only complaints flagged Fire=Y */
DECLARE @q3 VECTOR(768) = CAST(AI_GENERATE_EMBEDDINGS(N'search_query: the vehicle suddenly caught fire' USE MODEL OllamaNomic) AS VECTOR(768));
PRINT '=== H3 Expedition complaints about fire, Fire=Y only ===';
SELECT TOP (8) CAST(r.distance AS decimal(9,4)) AS dist, c.ModelYear, c.Component, c.Injured, LEFT(c.Narrative,80) AS complaint
FROM VECTOR_SEARCH(TABLE=dbo.ComplaintVectors AS cv, COLUMN=Embedding, SIMILAR_TO=@q3, METRIC='cosine', TOP_N=400) AS r
JOIN dbo.Complaints c ON c.ComplaintRowID = cv.ComplaintRowID
WHERE c.Fire = 'Y'
ORDER BY r.distance;
GO
