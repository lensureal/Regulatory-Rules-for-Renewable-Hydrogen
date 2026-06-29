### helper functions ###
# read the csv files
readcsv(x; dir=@__DIR__) = CSV.read(joinpath(dir, x), DataFrame, stringtype=String)
# readin function for parameters
readin(x::AbstractDataFrame; default=0,dims=1) = DefaultDict(default,Dict((dims > 1 ? Tuple(row[y] for y in 1:dims) : row[1]) => row[dims+1] for row in eachrow(x)))
readin(x::AbstractString; dir=@__DIR__, kwargs...) = readin(readcsv(x, dir=dir); kwargs...)


# generate result csv files from result data
function process_dataframes(tag::String="default")
    # Create the DataFrames from Containers.rowtable
    df_production = DataFrame(Containers.rowtable(value, FuelProductionByTechnology*8760/n_hour; header = [:Year,:Region, :Hour, :Technology, :Fuel, :Value]))
    df_unmet_demand = DataFrame(Containers.rowtable(value, UnmetDemand; header = [:Year,:Region, :Hour, :Fuel, :Value]))
    df_unmet_demand.Technology .= "UnmetDemand"
    df_use = DataFrame(Containers.rowtable(value, FuelUseByTechnology*8760/n_hour; header = [:Year,:Region, :Hour, :Technology, :Fuel, :Value]))
    df_capacity_total = DataFrame(Containers.rowtable(value, AccumulatedCapacity; header = [:Year,:Region, :Technology, :Value]))
    df_capacity_new = DataFrame(Containers.rowtable(value, NewCapacity; header = [:Year,:Region, :Technology, :Value]))

    df_storage_production = DataFrame(Containers.rowtable(value, StorageDischarge*8760/n_hour; header = [:Year,:Region, :Technology, :Hour, :Fuel, :Value]))
    df_storage_charge = DataFrame(Containers.rowtable(value, StorageCharge*8760/n_hour; header = [:Year,:Region, :Technology, :Hour, :Fuel, :Value]))
    df_storage_level = DataFrame(Containers.rowtable(value, StorageLevel*8760/n_hour; header = [:Year,:Region, :Storage, :Hour, :Fuel, :Value]))

    df_emissions = DataFrame(Containers.rowtable(value, AnnualTechnologyEmissions; header = [:Year,:Region, :Technology, :Value]))

    # Create the demand DataFrame
    df_demand = DataFrame(
        (Year=y,Region=r, Hour=h, Technology="Demand", Fuel=f, Value=Demand[y,r,f]*DemandProfile[r,h,f]) for y in year,r in regions, f in fuels, h in hour
    )

    if tag != "template"
        # Process export DataFrame
        df_export = DataFrame(Containers.rowtable(value, Export*8760/n_hour; header = [:Year,:From, :To, :Hour, :Fuel, :Value]))
        df_export.Technology .= "Export"
        df_export_grouped = combine(groupby(df_export, [:Year,:From, :Hour, :Technology, :Fuel]), :Value => sum => :Value)
        rename!(df_export_grouped, :From => :Region)

        # Process import DataFrame
        df_import = DataFrame(Containers.rowtable(value, Import*8760/n_hour; header = [:Year,:To, :From, :Hour, :Fuel, :Value]))
        df_import.Technology .= "Import"
        df_import_grouped = combine(groupby(df_import, [:Year,:To, :Hour, :Technology, :Fuel]), :Value => sum => :Value)
        rename!(df_import_grouped, :To => :Region)
    end

    # Generate Energy Balance Dataframe
    df_energybalance = df_use
    append!(df_energybalance, df_demand)
    append!(df_energybalance, df_storage_charge)
    if tag != "template" append!(df_energybalance, df_export_grouped) end
    df_energybalance.Value .= df_use.Value .* -1
    append!(df_energybalance, df_production)
    append!(df_energybalance,df_unmet_demand)
    append!(df_energybalance, df_storage_production)
    if tag != "template" append!(df_energybalance, df_import_grouped) end

    if tag != "template"
        # Generate Export/Import DataFrame
        df_trade = df_export
        append!(df_trade, df_import)
    end

    insertcols!(df_capacity_new, :Type => "NewCapacity")
    insertcols!(df_capacity_total, :Type => "AccumulatedCapacity")
    df_capacity = df_capacity_new
    append!(df_capacity, df_capacity_total)

    print("Successfully created the DataFrames :)")

    # Return the processed DataFrames
    if tag != "template"
        return df_energybalance,df_capacity,df_storage_level,df_trade,df_emissions
    elseif tag == "template"
        return df_energybalance,df_capacity,df_storage_level,df_emissions
    end
end

function write_result_csvs(tag::String="default",version::String="")
    # Define the path to the results directory
    result_path = mkpath(joinpath(@__DIR__, "results"))

    # write results to results directory in csv files
    CSV.write(joinpath(result_path, "EnergyBalance"*version*".csv"), df_energybalance)
    CSV.write(joinpath(result_path, "Capacity"*version*".csv"), df_capacity)
    CSV.write(joinpath(result_path, "StorageLevel"*version*".csv"), df_storage_level)
    CSV.write(joinpath(result_path, "Emissions"*version*".csv"), df_emissions)
    if tag != "template"
        CSV.write(joinpath(result_path, "DetailedTrade"*version*".csv"), df_trade)
    end
    obj_value = DataFrame(ObjectiveValue = objective_value(ESM))
    CSV.write(joinpath(result_path, "ObjectiveValue"*version*".csv"), obj_value)

    print("Successfully wrote CSVs to the result folder :)")
end


print("done")