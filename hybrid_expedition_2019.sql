USE NHTSA;
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET NOCOUNT ON;

-- how many 2019 Expedition complaints have a narrative (i.e. are searchable)?
SELECT COUNT(*) AS searchable_2019_expedition
FROM dbo.Complaints c JOIN dbo.ComplaintVectors cv ON cv.ComplaintRowID = c.ComplaintRowID
WHERE c.Make='FORD' AND c.Model='EXPEDITION' AND c.ModelYear=2019;

-- HYBRID: your relational filter, ranked by semantic similarity to a phrase
DECLARE @q  NVARCHAR(400) = N'the engine stalls or loses power while driving';   -- <<< change this phrase
DECLARE @qv VECTOR(768) = CAST(AI_GENERATE_EMBEDDINGS(N'search_query: ' + @q USE MODEL OllamaNomic) AS VECTOR(768));

SELECT TOP (15)
       CAST(1.0 - VECTOR_DISTANCE('cosine', cv.Embedding, @qv) AS decimal(9,4)) AS similarity,
       c.CmplID, c.ModelYear, c.Component, c.Crash, c.Fire, c.Injured, c.FailDate,
       LEFT(c.Narrative, 95) AS narrative
FROM dbo.Complaints c
JOIN dbo.ComplaintVectors cv ON cv.ComplaintRowID = c.ComplaintRowID
WHERE c.Make = 'FORD' AND c.Model = 'EXPEDITION' AND c.ModelYear = 2019
ORDER BY VECTOR_DISTANCE('cosine', cv.Embedding, @qv);   -- closest match first
