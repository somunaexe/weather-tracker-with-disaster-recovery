const express = require("express");
const axios = require("axios");
const cors = require("cors");
const AWS = require("aws-sdk");
const path = require("path");

const app = express();
app.use(cors());
app.use(express.json());

// serve the frontend from the public folder
app.use(express.static(path.join(__dirname, "../frontend")));

const PORT = process.env.PORT || 3000;
const WEATHER_API_KEY = process.env.WEATHER_API_KEY;
const S3_BUCKET = process.env.S3_BUCKET || "weather-tracker-weather-data";
const AWS_REGION = process.env.AWS_REGION || "eu-west-2";

// s3 client for storing weather data
const s3 = new AWS.S3({ region: AWS_REGION });

// health check endpoint - Route53 pings this every 30 seconds
// if this returns anything other than 200, failover to Azure kicks in
app.get("/health", (req, res) => {
  res.status(200).json({ status: "healthy", cloud: "aws" });
});

// fetches current weather for a city from OpenWeatherMap
app.get("/api/weather/:city", async (req, res) => {
  try {
    const { city } = req.params;
    const response = await axios.get(
      `https://api.openweathermap.org/data/2.5/weather?q=${city}&appid=${WEATHER_API_KEY}&units=metric`
    );

    const weatherData = {
      city: response.data.name,
      temperature: response.data.main.temp,
      feels_like: response.data.main.feels_like,
      humidity: response.data.main.humidity,
      description: response.data.weather[0].description,
      wind_speed: response.data.wind.speed,
      timestamp: new Date().toISOString(),
      cloud: "aws"
    };

    // save the weather data to S3 for historical tracking
    await s3.putObject({
      Bucket: S3_BUCKET,
      Key: `weather/${city}/${Date.now()}.json`,
      Body: JSON.stringify(weatherData),
      ContentType: "application/json"
    }).promise();

    res.json(weatherData);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// fetches 5 day forecast for a city
app.get("/api/forecast/:city", async (req, res) => {
  try {
    const { city } = req.params;
    const response = await axios.get(
      `https://api.openweathermap.org/data/2.5/forecast?q=${city}&appid=${WEATHER_API_KEY}&units=metric`
    );

    const forecast = response.data.list.map(item => ({
      datetime: item.dt_txt,
      temperature: item.main.temp,
      description: item.weather[0].description,
      humidity: item.main.humidity,
      wind_speed: item.wind.speed
    }));

    res.json({ city: response.data.city.name, forecast });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Weather tracker running on port ${PORT}`);
});
