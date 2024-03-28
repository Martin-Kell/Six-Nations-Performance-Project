-- Data sourced from Kaggle, URL: https://www.kaggle.com/datasets/lylebegbie/international-rugby-union-results-from-18712022

-- Project idea was from and done with, GitHub URL: https://github.com/jeanpierre

-- Looking at the data to decide what to clean and query later.

SELECT * 
FROM ResultsCleaning

-- We want to clean the competition column so that we can group all of the Six Nations Championships. 

SELECT *, REPLACE(Competition,Competition,'Six Nations Championship') as Competition_Cleaned
FROM ResultsCleaning
WHERE Competition Like'%Six Nations%'

-- We want to update the table so that Competition is now replaced by the Competition_Cleaned.

SELECT *
FROM ResultsCleaning
UPDATE ResultsCleaning
SET Competition = REPLACE(Competition,Competition,'Six Nations Championship')
WHERE Competition Like'%Six Nations%'

-- Checking the Update to the Competition column.

SELECT *
FROM ResultsCleaning
WHERE Date >= '2000-01-01' AND Competition Like'%Six Nations%'

-- Creating a Table for Six nations data only, and insert the data from ResultsCleaning.

DROP TABLE if exists SixNationsData
CREATE TABLE SixNationsData
(Date date,
Home_team nvarchar(50),
Away_team nvarchar(50),
Home_score int,
Away_score int,
Competition nvarchar(255),
Stadium nvarchar(50),
City nvarchar(50),
Neutral nvarchar(50),
World_cup nvarchar(50)
)

INSERT INTO SixNationsData (Date, Home_team, Away_team, Home_score, Away_score, Competition, Stadium, City, Neutral, World_cup)
SELECT Date, Home_team, Away_team, Home_score, Away_score, Competition, Stadium, City, Neutral, World_cup
FROM ResultsCleaning
WHERE Date >= '2000-01-01' AND Competition Like'%Six Nations%'

-- Now I want to drop the columns I don't want to use.

ALTER TABLE SixNationsData
DROP COLUMN Neutral, World_cup;

-- Adding a Winner and a HomeOrAwayWin column and Inserting data into them.

	-- Adding the columns.

ALTER TABLE SixNationsData
ADD Winner nvarchar(50)

ALTER TABLE SixNationsData
ADD HomeOrAwayWin nvarchar(50)

	-- Inserting data into the columns.

UPDATE SixNationsData
Set Winner = 
CASE 
    WHEN Home_score > Away_score THEN Home_team
    WHEN Away_score > Home_score THEN Away_team 
ELSE 'Draw'
END

UPDATE SixNationsData
Set HomeOrAwayWin = 
CASE 
    WHEN Home_score > Away_score THEN 'Home'
    WHEN Away_score > Home_score THEN 'Away' 
ELSE 'Draw'
END

-- Reformating the stadium names.

SELECT *, REPLACE(Stadium, Stadium, 'Murrayfield Stadium') as Stadium
FROM SixNationsData
WHERE Stadium Like'%Murrayfield%'

SELECT *, REPLACE(Stadium, Stadium, 'Twickenham Stadium') as Stadium
FROM SixNationsData
WHERE Stadium Like'%Twickenham%'

-- Updating the stadium names.

SELECT *
FROM SixNationsData
UPDATE SixNationsData
SET Stadium = REPLACE(Stadium, Stadium, 'Murrayfield Stadium')
WHERE Stadium Like'%Murrayfield%'

SELECT *
FROM SixNationsData
UPDATE SixNationsData
SET Stadium = REPLACE(Stadium, Stadium, 'Twickenham Stadium')
WHERE Stadium Like'%Twickenham%'

-- Checking Updates

SELECT *
FROM SixNationsData

-- Making a new table for coaches for each game.

DROP TABLE if exists NationCoaches
CREATE TABLE NationCoaches
(Date date,
EnglandCoach nvarchar(50),
FranceCoach nvarchar(50),
IrelandCoach nvarchar(50),
ItalyCoach nvarchar(50),
ScotlandCoach nvarchar(50),
WalesCoach nvarchar(50)
)

SELECT *
FROM NationCoaches

-- Queries for the SixNationsData

-- 1. Total Home and Away Wins and Awaw, Home and Draw Percentage.

SELECT HomeOrAwayWin, COUNT(HomeOrAwayWin) as Count, 
	(SELECT COUNT(HomeOrAwayWin) 
	FROM SixNationsData) as TotalMatches, 
	ROUND((COUNT(HomeOrAwayWin)/CAST((SELECT COUNT(HomeOrAwayWin) 
	FROM SixNationsData) as float))*100, 2) as Percentage
FROM SixNationsData
GROUP BY HomeOrAwayWin
ORDER BY Percentage DESC

-- 2. Biggest point difference.

SELECT Home_team, Away_team, Home_score, Away_score, Winner,
ABS(Home_score - Away_score) as Point_Difference
FROM SixNationsData
ORDER BY Point_Difference DESC 
		
	-- Adding Point_Difference to SixNationsData

ALTER TABLE SixNationsData
ADD Point_Difference int

UPDATE SixNationsData
Set Point_Difference = ABS(Home_score - Away_score)

SELECT *
FROM SixNationsData

	--2.1 AVG point difference per year.

		-- Because there is rounding errors from the AVG function I had to use CAST and ROUND to get a better estimation.

SELECT DATEPART(YEAR, Date) as Year, ROUND(AVG(CAST(Point_Difference as float)),0) as AVG_Point_Difference
FROM SixNationsData
GROUP BY DATEPART(YEAR, Date)

		-- Same Thing but using a CTE.

WITH CTE_AVGPointDiff as
(SELECT DATEPART(YEAR, Date) as Year, Point_Difference
FROM SixNationsData
)
SELECT Year, ROUND(AVG(CAST(Point_Difference as float)),0) as AVG_Point_Difference
FROM CTE_AVGPointDiff
GROUP BY Year
ORDER BY Year

	--2.2 AVG point difference per team.

SELECT Winner, ROUND(AVG(CAST(Point_Difference as float)),0) as AVG_Point_Difference
FROM SixNationsData
GROUP BY Winner
ORDER BY AVG_Point_Difference DESC

-- 3. Total score per year.

SELECT DATEPART(YEAR, Date) as Year, ROUND(AVG(Home_score + Away_score), 2) as AVGScore
FROM SixNationsData
GROUP BY DATEPART(YEAR, Date)

-- 4. Home and Away wins per team.

SELECT Winner, COUNT(Winner) as Count, HomeOrAwayWin
FROM SixNationsData
GROUP BY Winner, HomeOrAwayWin
ORDER BY HomeOrAwayWin, Count DESC

-- 5. Team win rate per year.

SELECT DATEPART(YEAR, Date) AS Year, Winner, COUNT(Winner) as Win_Count,
CAST(COUNT(Winner) as float)/5*100 AS Percentage_Of_Games_Won
FROM SixNationsData
GROUP BY DATEPART(YEAR, Date), Winner
ORDER BY DATEPART(YEAR, Date) ASC

-- 6. Win rate per statium for each team. 

	-- Create two temporary tables, one for Games at home and one for Wins at home.

DROP TABLE IF EXISTS #temp_GamesAtHome
CREATE TABLE #temp_GamesAtHome (
Home_team nvarchar(50),
Stadium nvarchar(50),
GamesAtHome int)

DROP TABLE IF EXISTS #temp_WinsAtHome
CREATE TABLE #temp_WinsAtHome (
Home_team nvarchar(50),
Stadium nvarchar(50),
WinsAtHome int)

	-- Inserting the data from SixNationsData into the temporary tables.

INSERT INTO #temp_GamesAtHome
SELECT Home_team, Stadium, COUNT(Stadium) as GamesAtHome
FROM SixNationsData
GROUP BY Home_team, Stadium
ORDER BY Home_team

INSERT INTO #temp_WinsAtHome
SELECT Home_team, Stadium, COUNT(Stadium)as WinsAtHome
FROM SixNationsData
WHERE HomeOrAwayWin = 'Home'
GROUP BY Stadium, Home_team
ORDER BY Home_team

	-- Join the two temporary tables by the same stadium name, select the wanted columns and calculate the win rate per stadium.

SELECT GAH.Home_team, GAH.Stadium, WinsAtHome, GamesAtHome,
	(SELECT ROUND((WinsAtHome/CAST(GamesAtHome as float))*100, 2)) as Percentage
FROM #temp_GamesAtHome GAH
LEFT OUTER JOIN #temp_WinsAtHome WAH
	ON GAH.Stadium = WAH.Stadium
	ORDER BY Percentage DESC

-- 7. Working out the Scores in England Games

	-- 7.1 

SELECT Date,
CASE 
	WHEN Home_team = 'England' THEN Home_team
	WHEN Away_team = 'England' THEN Away_team
END as England,
CASE 
	WHEN Home_team <> 'England' THEN Home_team
	WHEN Away_team <> 'England' THEN Away_team
END as Opposition,
CASE 
	WHEN Home_team = 'England' THEN Home_score
	WHEN Away_team = 'England' THEN Away_score
END as Englands_Score,
CASE 
	WHEN Home_team <> 'England' THEN Home_score
	WHEN Away_team <> 'England' THEN Away_score
END as Oppositions_Score,
(Home_score + Away_score) as Combined_score
FROM SixNationsData
WHERE Home_team = 'England' OR Away_team = 'England'
ORDER BY Opposition, Date

	-- 7.2 Englands percentage Win rate against each team.

		-- England vs Ireland

SELECT winner, COUNT(winner) as Wins
FROM SixNationsData
WHERE (Home_team = 'England' AND Away_team = 'Ireland') OR (Away_team = 'England' AND Home_team = 'Ireland')
GROUP BY winner

		-- England vs France

SELECT winner, COUNT(winner) as Wins
FROM SixNationsData
WHERE (Home_team = 'England' AND Away_team = 'France') OR (Away_team = 'England' AND Home_team = 'France')
GROUP BY winner

		-- England vs Wales

SELECT winner, COUNT(winner) as Wins
FROM SixNationsData
WHERE (Home_team = 'England' AND Away_team = 'Wales') OR (Away_team = 'England' AND Home_team = 'Wales')
GROUP BY winner

		-- England vs Scotland

SELECT winner, COUNT(winner) as Wins
FROM SixNationsData
WHERE (Home_team = 'England' AND Away_team = 'Scotland') OR (Away_team = 'England' AND Home_team = 'Scotland')
GROUP BY winner

		-- England vs Italy

SELECT winner, COUNT(winner) as Wins
FROM SixNationsData
WHERE (Home_team = 'England' AND Away_team = 'Italy') OR (Away_team = 'England' AND Home_team = 'Italy')
GROUP BY winner 
	
-- Testing and Extra Queries.

SELECT Winner, COUNT(Winner) as Count, 
	(SELECT COUNT(Winner) 
	FROM SixNationsData) as TotalMatches, 
	ROUND((COUNT(Winner)/CAST((SELECT COUNT(Winner) 
	FROM SixNationsData) as float))*100, 2) as Percentage
FROM SixNationsData
GROUP BY Winner
ORDER BY Percentage DESC
