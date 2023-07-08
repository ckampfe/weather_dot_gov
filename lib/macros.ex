defmodule WeatherDotGov.Macros do
  @moduledoc false

  defmacro __using__(options) do
    api_definition = options[:definition] || "openapi.json"

    %{
      "openapi" => openapi,
      "info" => info,
      "servers" => servers,
      "paths" => paths
    } =
      api_definition
      |> File.read!()
      |> Jason.decode!()

    server =
      servers
      |> Enum.find(servers, fn server ->
        Map.fetch!(server, "url")
      end)
      |> Map.fetch!("url")

    operations =
      Enum.map(paths, fn {path, path_def} ->
        function_name =
          path_def
          |> get_in(["get", "operationId"])
          |> Recase.to_snake()

        function_docs = get_in(path_def, ["get", "description"])

        params =
          Regex.scan(~r/\{(?<param>\w+)\}/, path)
          |> Enum.map(fn [_match, param] ->
            param
          end)

        snaked_params =
          params
          |> Enum.map(fn arg ->
            Recase.to_snake(arg)
          end)

        # so we can construct an argument list with actual names, like
        # def func(a, b, c)
        function_args =
          snaked_params
          |> Enum.map(fn param ->
            param
            |> String.to_atom()
            |> Macro.var(nil)
          end)

        # construct an EEx template so we can do a string replace
        # on the given request path schema, like:
        # `/alerts/active/zone/<%= zoneId %>` to `/alerts/active/zone/MN`
        url =
          (server <>
             (params
              |> Enum.zip(snaked_params)
              |> Enum.reduce(path, fn {original_param, snaked_param}, acc ->
                String.replace(acc, "{#{original_param}}", "<%= #{snaked_param} %>")
              end)))
          |> EEx.compile_string()

        %{
          function_name: function_name,
          function_docs: function_docs,
          function_args: function_args,
          url: url
        }
      end)

    quote bind_quoted: [
            openapi: Macro.escape(openapi),
            info: Macro.escape(info),
            servers: Macro.escape(servers),
            operations: Macro.escape(operations)
          ] do
      def open_api_version() do
        unquote(openapi)
      end

      def info() do
        unquote(Macro.escape(info))
      end

      def servers() do
        unquote(Macro.escape(servers))
      end

      Enum.each(operations, fn
        %{
          function_name: function_name,
          function_docs: function_docs,
          function_args: function_args,
          url: url
        } ->
          @doc function_docs
          def unquote(String.to_atom(function_name))(unquote_splicing(function_args)) do
            {:ok, resp} = Req.get(unquote(url))

            {"content-type", content_type} = :lists.keyfind("content-type", 1, resp.headers)

            case content_type do
              "application/ld+json" ->
                {:ok, Map.put(resp, :body, Jason.decode!(resp.body))}

              "application/vnd.wmo.iwxxm+xml" ->
                {:ok, Map.put(resp, :body, SweetXml.parse(resp.body))}

              _ ->
                {:ok, resp}
            end
          end
      end)
    end
  end
end
