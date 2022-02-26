using Genie
using Statistics
using ThreadsX

function v_asian_sample(T, X0, K, r, sd, m)::Float64
    X = X0
    sumX = X
    d = T / m
    for i in 1:m
        X *= exp((r-sd^2/2)*d + sd*sqrt(d)*randn())
        sumX += X
    end
    return exp(-r*T) * max(sumX / (m + 1) - K, 0)
end

function v_asian_value(T, X0, K, r, sd, m, max_time)
    result = Float64[]
    start_time = time()
    while time() - start_time < max_time
        append!(result, ThreadsX.map(_ -> v_asian_sample(T, X0, K, r, sd, m), 1:10_000))
    end
    n = length(result)
    mv = mean(result)
    sdv = std(result)
    lo95 = mv - 1.96 * sdv / sqrt(n)
    hi95 = mv + 1.96 * sdv / sqrt(n)
    zero = mean(==(0), result)
    return (; n, mv, sdv, lo95, hi95, zero)
end

Genie.config.run_as_server = true

Genie.Router.route("/", method=POST) do
  message = Genie.Requests.jsonpayload()
  return try
      K = float(message["K"])
      max_time = float(message["max_time"])
      value = v_asian_value(1.0, 50.0, K, 0.05, 0.3, 200, max_time)
      Genie.Renderer.Json.json((status="OK", value=value))
  catch
      Genie.Renderer.Json.json((status="ERROR", value=""))
  end
end

Genie.startup()