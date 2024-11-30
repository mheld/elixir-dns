defmodule DNS.Server do
  @moduledoc """
  DNS server based on `GenServer`.
  """

  @callback handle(DNS.Record.t(), {:inet.ip(), :inet.port()}) :: DNS.Record.t()

  defmacro __using__(_) do
    quote [] do
      use GenServer

      @doc """
      Start DNS.Server` server.

      ## Options

      * `:port` - set the port number for the server
      """
      def start_link(port) do
        GenServer.start_link(__MODULE__, [port])
      end

      def init([port]) do
        # try to get the IP address of the fly-global-services service,
        # but fallback to not binding to any specific IP address
        {:ok, socket} =
          case :inet.getaddr(~c"fly-global-services", :inet) do
            {:ok, addr} ->
              :gen_udp.open(port, [{:active, true}, {:mode, :binary}, {:ip, addr}])

            _ ->
              :gen_udp.open(port, [{:active, true}, {:mode, :binary}])
          end

        IO.puts("Server listening at #{port}")

        # accept_loop(socket, handler)
        {:ok, %{port: port, socket: socket}}
      end

      def handle_info({:udp, client, ip, port, data}, state) do
        record = DNS.Record.decode(data)
        response = handle(record, client)
        :gen_udp.send(state.socket, convert_address(ip), port, DNS.Record.encode(response))
        {:noreply, state}
      end

      defp convert_address(a) when is_binary(a), do: String.to_charlist(a)

      defp convert_address(a), do: a
    end
  end
end
