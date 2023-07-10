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

    param_regex = ~r/\{(\w+)\}/

    operations =
      Enum.map(paths, fn {path, path_def} ->
        function_name =
          path_def
          |> get_in(["get", "operationId"])
          |> Recase.to_snake()

        function_docs = get_in(path_def, ["get", "description"])

        # so we can construct an argument list with actual names, like
        # def func(a, b, c)
        function_args =
          Regex.scan(param_regex, path)
          |> Enum.map(fn [_match, param] ->
            param
            |> Recase.to_snake()
            |> String.to_atom()
            |> Macro.var(nil)
          end)

        # construct an EEx template so we can do a string replace
        # on the given request path schema, like:
        # `/alerts/active/zone/<%= zoneId %>` to `/alerts/active/zone/MN`
        url_template =
          (server <>
             Regex.replace(param_regex, path, fn _whole_match, param ->
               "<%= #{Recase.to_snake(param)} %>"
             end))
          |> EEx.compile_string()

        %{
          function_name: function_name,
          function_docs: function_docs,
          function_args: function_args,
          url_template: url_template
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
          url_template: url_template
        } ->
          @doc function_docs
          def unquote(String.to_atom(function_name))(unquote_splicing(function_args)) do
            response = Req.get(unquote(url_template))

            with {:http, {:ok, resp}} <- {:http, response},
                 {:content_type, {"content-type", content_type}} <-
                   {:content_type, :lists.keyfind("content-type", 1, resp.headers)} do
              case content_type do
                "application/ld+json" ->
                  {:ok, Map.put(resp, :body, Jason.decode!(resp.body))}

                "application/vnd.wmo.iwxxm+xml" ->
                  {:ok, Map.put(resp, :body, SweetXml.parse(resp.body))}

                _ ->
                  {:ok, resp}
              end
            else
              # `:lists.keyfind/3` returns `false` if it cannot kind
              # the an element with the given key, which in this case
              # would mean that the request did not have a `content-type` header,
              # so just return the raw response
              {:content_type, false} ->
                response

              # otherwise return whatever error the HTTP request happens to return
              {:http, {:error, _} = e} ->
                e
            end
          end
      end)
    end
  end
end
