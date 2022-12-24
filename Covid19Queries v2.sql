/*
Covid19 data exploration using the Coronavirus (COVID-19) Deaths dataset from https://ourworldindata.org/covid-deaths. 

Skills Used: Joins, CTE's Temp Tables, Windows Functions, Aggregate Functions, Views and Data Type Conversion.
*/


--OVERVIEW of each table.
SELECT * FROM CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, date;

SELECT * FROM CovidVax
WHERE continent IS NOT NULL
ORDER BY location, date

--The data used from the CovidDeaths table to make our initial analysis showing the location, date, total_cases, new_cases,
--and total_deaths. *The total_deaths column is an nvarchar(255) datatype.

SELECT 
	location,
	date,
	total_cases,
	new_cases,
	CAST(total_deaths AS INT) AS DailyDeaths
FROM CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, date;


--Daily Total Cases vs Daily Total Deaths: Showing the likelihood of dying if infected per country.
SELECT
	location,
	date,
	total_cases,
	CAST(total_deaths AS INT) AS TotalDeaths,
	ROUND(CAST(total_deaths AS INT)/total_cases*100, 2) AS DeathPercentage	
FROM CovidDeaths
WHERE continent IS NOT NULL 
ORDER BY location, date;


--Daily Total Cases vs Population: Showing the overall percentage of the population infected with Covid-19.
SELECT
	location,
	date,
	population,
	total_cases,
	total_cases/population*100 AS PercentPopulationInfected	
FROM CovidDeaths
GROUP BY location, date,total_cases,population
ORDER BY PercentPopulationInfected DESC;

--DBCC DropCleanBuffers

--Highest Infection Rate vs. Population: Showing countries with the highest infection count 
--and the overall highest percent of the population infected.

SELECT
	location,
	population,
	MAX(CAST(total_cases AS INT)) AS HighestInfectionCount,
	MAX((total_cases/population))*100 AS PercentPopulationInfected
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY PercentPopulationInfected DESC;


--Death count vs. Population: Countries with the Highest Death Count per Population.
SELECT
	location,
	MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY TotalDeathCount DESC;


--Death Count vs. Continent: Continents with the Highest Death Count.
SELECT
	location,
	MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM CovidDeaths
WHERE continent IS NULL AND location NOT IN('High income','Upper middle income','Lower middle income','Low income','International')
GROUP BY location
ORDER BY TotalDeathCount DESC;


--Total Cases vs. Continent: Continents with the Highest Infection Count.
SELECT
	location,
	MAX(CAST(total_cases AS INT)) AS TotalInfectionCount
FROM CovidDeaths
WHERE continent IS NULL AND location NOT IN('High income','Upper middle income','Lower middle income','Low income','International')
GROUP BY location
ORDER BY TotalInfectionCount DESC;


--Total New Cases & Deaths Global: Showing global statistics based on the number of new_cases and new_deaths.
SELECT
	SUM(new_cases) AS TotalGlobalCases,
	SUM(CAST(new_deaths AS int)) AS TotalGlobalDeaths,
	SUM(CAST(new_deaths AS int))/SUM(new_cases)*100 AS GlobalDeathPercentage
FROM CovidDeaths
WHERE continent IS NOT NULL;

--Vaccination Analysis: The data used from joining the CovidVax and CovidDeaths tables to make our initial analysis 
--showing the continent, location, date, population, new_vaccinations with a running total.
SELECT
	cd.continent,
	cd.location,
	cd.date,
	cd.population,
	CONVERT(bigint,cv.new_vaccinations) AS DailyVaccinations,
	SUM(CONVERT(bigint,cv.new_vaccinations)) OVER (PARTITION BY cd.location ORDER BY cd.location, cd.date ASC) AS RollingTotalVaccinations
FROM CovidDeaths AS cd
INNER JOIN CovidVax AS cv
	ON cd.location=cv.location AND cd.date=cv.date
WHERE cd.continent IS NOT NULL
GROUP BY cd.continent, cd.location,cd.date,cd.population,cv.new_vaccinations
ORDER BY location, date;

--USING a CTE on the above query to perform further analysis.
WITH VaxVsPop(continent,location,date,population,DailyNewVaccinations,RollingTotalVaccinations) AS (
SELECT
	cd.continent,
	cd.location,
	cd.date,
	cd.population,
	CONVERT(bigint,cv.new_vaccinations) AS DailyNewVaccinations,
	SUM(CONVERT(bigint,cv.new_vaccinations)) OVER (PARTITION BY cd.location ORDER BY cd.location, cd.date ASC) AS RollingTotalVaccinations
FROM CovidDeaths AS cd
JOIN CovidVax AS cv
	ON cd.location=cv.location AND cd.date=cv.date
WHERE cd.continent IS NOT NULL
)

SELECT *,
	(RollingTotalVaccinations/population)*100 AS PercentVaccinated
FROM VaxVsPop
ORDER BY location, date


--Using a Temp Table to perform further calculations and store as a view.
DROP TABLE IF EXISTS #PerentPopVaccinated

--Creating Temp Table
CREATE TABLE #PerentPopVaccinated (
	Continent nvarchar(255),
	Location nvarchar(255),
	Date datetime,
	Population numeric,
	DailyNewVaccinations numeric,
	RollingTotalVaccinations numeric
)
--Insert the query into the temp table.
INSERT INTO #PerentPopVaccinated
SELECT
	cd.continent,
	cd.location,
	cd.date,
	cd.population,
	CONVERT(bigint,cv.new_vaccinations) AS DailyNewVaccinations,
	SUM(CONVERT(bigint,cv.new_vaccinations)) OVER (PARTITION BY cd.location ORDER BY cd.location, cd.date ASC) AS RollingTotalVaccinations
FROM CovidDeaths AS cd
JOIN CovidVax AS cv
	ON cd.location=cv.location AND cd.date=cv.date
WHERE cd.continent IS NOT NULL;

SELECT *,
	(RollingTotalVaccinations/Population)*100
FROM #PerentPopVaccinated;

GO

--Creating View to store data for Tableau visualizations.
CREATE VIEW PercentPopVaccinated AS

SELECT
	cd.continent,
	cd.location,
	cd.date,
	cd.population,
	CONVERT(bigint,cv.new_vaccinations) AS DailyNewVaccinations,
	SUM(CONVERT(bigint,cv.new_vaccinations)) OVER (PARTITION BY cd.location ORDER BY cd.location, cd.date ASC) AS RollingTotalVaccinations
FROM CovidDeaths AS cd
JOIN CovidVax AS cv
	ON cd.location=cv.location AND cd.date=cv.date
WHERE cd.continent IS NOT NULL;