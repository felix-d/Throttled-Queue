defmodule ThrottledQueue.Mixfile do
  use Mix.Project

  def project do
    [
      app: :throttled_queue,
      package: package(),
      description: "A simple throttled queue built on top of GenServer with status updates.",
      version: "0.3.0-dev",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      name: "ThrottledQueue",
      source_url: "https://www.github.com/felix-d/throttled_queue",
    ]
  end

  defp package() do
    [
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Félix Descôteaux"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/felix-d/throttled_queue"}
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
    ]
  end
end
