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

    url_host =
      servers
      |> Enum.find(servers, fn server ->
        Map.fetch!(server, "url")
      end)
      |> Map.fetch!("url")

    param_regex = ~r/\{(\w+)\}/

    operations =
      Enum.map(paths, fn {url_path,
                          %{
                            "get" => %{
                              "operationId" => operation_id,
                              "description" => description
                            }
                          } = path_definition} ->
        function_name =
          Recase.to_snake(operation_id)

        function_docs = description

        # so we can construct an argument list with actual names, like
        # def func(a, b, c)
        function_args =
          Regex.scan(param_regex, url_path)
          |> Enum.map(fn [_match, param] ->
            param
            |> Recase.to_snake()
            |> String.to_atom()
            |> Macro.var(nil)
          end)

        # construct an EEx template so we can do a string replace
        # on the given request path schema, like:
        # `/alerts/active/zone/<%= zoneId %>` to `/alerts/active/zone/MN`
        url_path_template =
          Regex.replace(param_regex, url_path, fn _whole_match, param ->
            "<%= #{Recase.to_snake(param)} %>"
          end)

        url_template = EEx.compile_string(url_host <> url_path_template)

        # not all path definitions have the `deprecated` key,
        # so we have to get it this way rather than pattern match on it
        is_deprecated? =
          get_in(path_definition, ["get", "deprecated"])

        %{
          function_name: function_name,
          function_docs: function_docs,
          function_args: function_args,
          url_template: url_template,
          is_deprecated: is_deprecated?,
          url_path: url_path
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
          url_template: url_template,
          is_deprecated: is_deprecated?,
          url_path: url_path
        } ->
          if is_deprecated? do
            @deprecated "weather.gov has reports that this endpoint is deprecated."
          end

          @doc function_docs <> "\n\n" <> "Endpoint: " <> url_path
          def unquote(String.to_atom(function_name))(unquote_splicing(function_args)) do
            response = Req.get(unquote(url_template))

            with {:http, {:ok, resp}} <- {:http, response},
                 {:content_type, {"content-type", content_type}} <-
                   {:content_type, :lists.keyfind("content-type", 1, resp.headers)} do
              case content_type do
                "application/ld+json" ->
                  {:ok, Map.put(resp, :body, Jason.decode!(resp.body))}

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
