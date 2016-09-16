require Logger

defmodule Discovery do

  def act_on_failures(failure_report) do
      strike_3 = Enum.filter(
        failure_report,
        fn {service_string, failure_count} ->
          3 > failure_count
        end
      )
      Enum.map(strike_3,
        fn {service_string, count} ->
          IO.puts("deregistering multiple offender: #{inspect service_string}")
          ExSlp.Service.deregister
        end
      )
      failure_report = Enum.filter_map(failure_report,
      fn {k,v}-> v <= 3 end,
      fn {k,v}-> {k,v} end)|>Enum.into(%{})
  end
  def discover() do
    slp_services = ExSlp.Service.discover()
    {:ok, this_hostname} = :inet.gethostname()
    result = Enum.filter(
      slp_services,
      fn service_string ->
        # HACK:
        # by default service-strings are constructed with the human-friendly
        # system hostnames.  this project's `sys.config` config file requires
        # using an IP address.  what's up with that?
        normalized_string = String.replace(
          to_string(service_string),
          to_string(this_hostname),
          "127.0.0.1")
        should_skip = normalized_string==Atom.to_string(Node.self())
        unless(should_skip) do
          case ExSlp.Service.connect(normalized_string) do
            # see http://elixir-lang.org/docs/stable/elixir/Node.html#connect/1
            :ignored ->
              # Node.connect() ignored a down host
              #Logger.info("Connection to #{inspect normalized_string} ignored")
              nil
            false ->
              # Connection failed
              #Logger.info("Connection to #{inspect normalized_string} failed")
              nil
            true ->
              # Connection is successful (but not necessarily new)
              normalized_string
          end # case
        end # unless
        discover()
      end)
      msg = Functions.red("SLP Discovery: ")
      #Logger.info msg <> "#{inspect result}"
  end
  def register() do
    hostname ="127.0.0.1"
    port = "65535"
    {:ok, result} = ExSlp.Service.register()#{}"service:exslp://#{hostname},#{port}")
    Logger.info Functions.red("Ran registration task:")<>" ok"
  end
end
