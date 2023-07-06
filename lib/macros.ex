defmodule WeatherDotGov.Macros do
  @moduledoc false

  defmacro __using__(options) do
    api_definition = options[:definition] || "openapi.json"

    %{
      "openapi" => openapi,
      "info" => info,
      "servers" => servers,
      "paths" => paths,
      "components" => components
    } =
      api_definition
      |> File.read!()
      |> Jason.decode!()

    quote bind_quoted: [
            openapi: Macro.escape(openapi),
            info: Macro.escape(info),
            servers: Macro.escape(servers),
            paths: Macro.escape(paths),
            components: Macro.escape(components)
          ] do
      server =
        servers
        |> Enum.find(servers, fn server ->
          Map.fetch!(server, "url")
        end)
        |> Map.fetch!("url")

      def open_api_version() do
        unquote(openapi)
      end

      def info() do
        unquote(Macro.escape(info))
      end

      def servers() do
        unquote(Macro.escape(servers))
      end

      Enum.each(paths, fn {path, path_def} ->
        operation_name =
          path_def
          |> get_in(["get", "operationId"])
          |> Recase.to_snake()

        doc = get_in(path_def, ["get", "description"])

        params =
          Regex.scan(~r/\{(?<param>\w+)\}/, path)
          |> Enum.map(fn [_match, param] ->
            param
          end)

        if !Enum.empty?(params) do
          # so we can construct an argument list with actual names, like
          # def func(a, b, c)
          args =
            Enum.map(params, fn arg ->
              arg =
                arg
                |> Recase.to_snake()
                |> String.to_atom()

              Macro.var(arg, __MODULE__)
            end)

          # so we can do a string replace on the given request path schema,
          # like `/alerts/active/zone/{zoneId}` to `/alerts/active/zone/MN`
          replacer =
            quote do
              unquote(params)
              |> Enum.zip(unquote(args))
              |> Enum.reduce(unquote(path), fn {param, arg}, acc ->
                acc
                |> String.replace("{#{param}}", "#{arg}")
              end)
            end

          @doc doc
          def unquote(String.to_atom(operation_name))(unquote_splicing(args)) do
            full_path = unquote(server) <> unquote(replacer)

            {:ok, resp} = Req.get(full_path)

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
        else
          @doc doc
          def unquote(String.to_atom(operation_name))() do
            full_path = unquote(server) <> unquote(path)

            {:ok, resp} = Req.get(full_path)

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
        end
      end)
    end
  end
end
