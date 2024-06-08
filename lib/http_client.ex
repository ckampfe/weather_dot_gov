defmodule WeatherDotGov.HttpClient do
  @callback get(url :: URI.t() | String.t()) ::
              {:ok, response :: term} | {:error, error :: term}
end
