using JuMP # building models
using DataStructures # using dictionaries with a default value
using Gurobi # solver for the JuMP model
using CSV # readin of CSV files
using DataFrames # data tables
using Statistics # mean function
using Plots  # generate graphs
using Plots.Measures
using StatsPlots # additional features for plots
include(joinpath(@__DIR__, "colors.jl")) # colors for the plots
include(joinpath(@__DIR__, "helper_functions.jl")) # helper functions

data_dir = joinpath(@__DIR__, "data")

version = "_00_default"

### Read in of parameters ###
# We define our sets from the csv files
technologies = readcsv("technologies.csv", dir=data_dir).technology
fuels = readcsv("fuels.csv", dir=data_dir).fuel
storages = readcsv("storages.csv", dir=data_dir).storage
hour = 1:120
n_hour = length(hour)
regions = readcsv("regions.csv", dir=data_dir).region

# also, we need a set for our years
year = 2020:10:2050

# Also, we read our input parameters via csv files
Demand = readin("demand_regions.csv", dims=3, dir=data_dir)
OutputRatio = readin("outputratio.csv", dims=2, dir=data_dir)
InputRatio = readin("inputratio.csv", dims=2, dir=data_dir)
VariableCost = readin("variablecost.csv", dims=2, dir=data_dir)
InvestmentCost = readin("investmentcost.csv", dims=2, dir=data_dir)
EmissionRatio = readin("emissionratio.csv", dims=1, dir=data_dir)
EmissionContentOfFuel = readin("emissioncontentperfuel.csv", dims=1, dir=data_dir)
DemandProfile = readin("demandprofile_regions.csv", default=1/n_hour, dims=3, dir=data_dir)
CapacityFactor = readin("capacity_factors_regions.csv",default=0, dims=3, dir=data_dir)
TagDispatchableTechnology = readin("tagdispatchabletechnology.csv",default=1,dims=1, dir=data_dir)

# we need to read in region and year dependent unmetdemandpenalty
UnmetDemandPenalty = readin("unmetdemandpenalty.csv", default=9999, dims=2, dir=data_dir)

# we need to ensure that all non-variable technologies do have a CapacityFactor of 1 at all times
for r in regions    
    for t in technologies
        if TagDispatchableTechnology[t] > 0
            for h in hour
                CapacityFactor[r,h,t] = 1
            end
        else 
            for h in hour
                CapacityFactor[r,h,t] = min(CapacityFactor[r,h,t],1)
            end        
        end
    end
end

### Also, we need to read in our additional storage parameters
InvestmentCostStorage = readin("investmentcoststorage.csv",dims=2, dir=data_dir)
E2PRatio = readin("e2pratio.csv",dims=1, dir=data_dir)
StorageChargeEfficiency = readin("storagechargeefficiency.csv",dims=2, dir=data_dir)
StorageDischargeEfficiency = readin("storagedischargeefficiency.csv",dims=2, dir=data_dir)
MaxStorageCapacity = readin("maxstoragecapacity.csv",default=50,dims=3, dir=data_dir)
StorageLosses = readin("storagelosses.csv",default=1,dims=2, dir=data_dir)

# our yearly emission limit
AnnualEmissionLimit = readin("annualemissionlimit.csv",default=999999,dims=1, dir=data_dir)
RegionalAnnualEmissionLimit = readin("regionalannualemissionlimit.csv",default=999999,dims=2, dir=data_dir)

#our discount rate
DiscountRate = 0.05

# stuff for emission trajectories
ModelPeriodEmissionLimit = 25500000

# create a multiplier to weight the different years correctly
YearlyDifferenceMultiplier = Dict()
for i in 1:length(year)-1
    difference = year[i+1] - year[i]
    # Store the difference in the dictionary
    YearlyDifferenceMultiplier[year[i]] = difference
end
YearlyDifferenceMultiplier[year[end]] = 1
# this gives us the distance between each year for all years
YearlyDifferenceMultiplier

# define the dictionary for max capacities with specific default value
MaxCapacity = readin("maxcapacity.csv", default=999, dims=3, dir=data_dir)
MaxTradeCapacity = readin("maxtradecapacity.csv", default=0, dims=4, dir=data_dir)
ResidualCapacity = readin("residualcapacity.csv", default=0, dims=3, dir=data_dir)
TechnologyLifetime = readin("technologylifetime.csv", default=10, dims=1, dir=data_dir)

# add your trade distances and other trade parameters
TradeDistance = readin("tradedistance.csv",default=0,dims=2, dir=data_dir)
TradeCostFactor = readin("tradecostfactor.csv",default=0,dims=1, dir=data_dir)
TradeLossFactor = readin("tradelossfactor.csv",default=0,dims=1, dir=data_dir)

### building the model ###
# instantiate a model with an optimizer
ESM = Model(Gurobi.Optimizer)
set_optimizer_attribute(ESM, "Threads", 3)

# this creates our variables
@variable(ESM, TotalCost[year,regions,technologies] >= 0)
@variable(ESM, FuelProductionByTechnology[year,regions,hour,t = technologies,f = fuels; OutputRatio[t,f]>0] >= 0)
@variable(ESM, NewCapacity[year,regions,technologies] >=0)
@variable(ESM, AccumulatedCapacity[year,regions,technologies] >=0)
@variable(ESM, FuelUseByTechnology[year,regions,hour,t = technologies,f = fuels; InputRatio[t,f]>0] >=0)
@variable(ESM, AnnualTechnologyEmissions[year,regions,technologies])
@variable(ESM, Curtailment[year,regions,hour,fuels] >=0)

### And we also need to add our new variables for storages
@variable(ESM, NewStorageEnergyCapacity[year,regions,s=storages,f=fuels; StorageDischargeEfficiency[s,f]>0]>=0)
@variable(ESM, AccumulatedStorageEnergyCapacity[year,regions,s=storages,f=fuels; StorageDischargeEfficiency[s,f]>0]>=0)
@variable(ESM, StorageCharge[year,regions,s=storages, hour, f=fuels; StorageDischargeEfficiency[s,f]>0]>=0)
@variable(ESM, StorageDischarge[year,regions,s=storages, hour, f=fuels; StorageDischargeEfficiency[s,f]>0]>=0)
@variable(ESM, StorageLevel[year,regions,s=storages, hour, f=fuels; StorageDischargeEfficiency[s,f]>0]>=0)
@variable(ESM, TotalStorageCost[year,regions,storages] >= 0)

##### now, we also need new variables for trade between regions
@variable(ESM, Import[y = year,r = regions,rr = regions,hour,f = fuels; MaxTradeCapacity[y,r,rr,f]>0] >= 0)
@variable(ESM, Export[y = year,r = regions,rr = regions,hour,f = fuels; MaxTradeCapacity[y,r,rr,f]>0] >= 0)

@variable(ESM, SalvageValue[year,regions,technologies] >= 0)

# we introduce a new variable to catch a lack in supply options, we will call this UnmetDemand
@variable(ESM, UnmetDemand[year,regions,hour,fuels] >= 0)

#@variable(ESM, CapacitySlack[year,regions,technologies] >= 0)

## constraints ##
# Generation must meet demand
@constraint(ESM, EnergyBalance[y in year,r in regions,h in hour,f in fuels],
    (sum(FuelProductionByTechnology[y,r,h,t,f] for t in technologies if OutputRatio[t,f]>0) 
    + sum(StorageDischarge[y,r,s,h,f] for s in storages if StorageDischargeEfficiency[s,f]>0) 
    + sum(Import[y,r,rr,h,f] for rr in regions if MaxTradeCapacity[y,r,rr,f]>0))*8760/n_hour
    # we can now add UnmetDemand to the production side of the energy balance
    + UnmetDemand[y,r,h,f] == 
    Demand[y,r,f]*DemandProfile[r,h,f] 
    + (sum(FuelUseByTechnology[y,r,h,t,f] for t in technologies if InputRatio[t,f]>0) 
    + Curtailment[y,r,h,f] 
    + sum(StorageCharge[y,r,s,h,f] for s in storages if StorageChargeEfficiency[s,f] > 0)
    + sum(Export[y,r,rr,h,f] for rr in regions if MaxTradeCapacity[y,r,rr,f]>0))*8760/n_hour
)

# calculate the total cost
@constraint(ESM, ProductionCost[y in year,r in regions,t in technologies],
    sum(FuelProductionByTechnology[y,r,h,t,f] for f in fuels, h in hour if OutputRatio[t,f]>0) * VariableCost[y,t]  * YearlyDifferenceMultiplier[y] * 8760/n_hour + NewCapacity[y,r,t] * InvestmentCost[y,t] == TotalCost[y,r,t]
)

# limit the production by the installed capacity
@constraint(ESM, ProductionFunction_disp[y in year,r in regions,h in hour, t in technologies, f in fuels;TagDispatchableTechnology[t]>0 && OutputRatio[t,f]>0],
    OutputRatio[t,f] * AccumulatedCapacity[y,r,t] * CapacityFactor[r,h,t] >= FuelProductionByTechnology[y,r,h,t,f]
)

# for variable renewables, the production needs to be always at maximum
@constraint(ESM, ProductionFunction_res[y in year,r in regions,h in hour, t in technologies, f in fuels;TagDispatchableTechnology[t]==0 && OutputRatio[t,f]>0],
    OutputRatio[t,f] * AccumulatedCapacity[y,r,t] * CapacityFactor[r,h,t] == FuelProductionByTechnology[y,r,h,t,f]
)

# define the use by the production
@constraint(ESM, UseFunction[y in year,r in regions,h in hour,t in technologies, f in fuels; InputRatio[t,f]>0],
    InputRatio[t,f] * sum(FuelProductionByTechnology[y,r,h,t,ff] for ff in fuels if OutputRatio[t,ff]>0) == FuelUseByTechnology[y,r,h,t,f]
)

# define the emissions
@constraint(ESM, TechnologyEmissionFunction[y in year,r in regions,t in technologies],
    sum(FuelUseByTechnology[y,r,h,t,f] * EmissionContentOfFuel[f] for f in fuels, h in hour if InputRatio[t,f]>0)*8760/n_hour * EmissionRatio[t]  == AnnualTechnologyEmissions[y,r,t]
)

# limit the emissions in each individual year
@constraint(ESM, AnnualEmissionsLimitFunction[y in year],
    sum(AnnualTechnologyEmissions[y,r,t] for t in technologies for r in regions) <= AnnualEmissionLimit[y]
)

# now also limit the emissions in each individual year for each region
@constraint(ESM, RegionalAnnualEmissionsLimitFunction[y in year,r in regions],
    sum(AnnualTechnologyEmissions[y,r,t] for t in technologies) <= RegionalAnnualEmissionLimit[y,r]
)

# installed capacity is limited by the maximum capacity
@constraint(ESM, MaxCapacityFunction[y in year,r in regions,t in technologies],
     AccumulatedCapacity[y,r,t] <= MaxCapacity[y,r,t]
)

### Add your storage constraints here
@constraint(ESM, StorageChargeFunction[y in year,r in regions,s in storages, h in hour, f in fuels; StorageDischargeEfficiency[s,f]>0], 
    StorageCharge[y,r,s,h,f] <= AccumulatedStorageEnergyCapacity[y,r,s,f]/E2PRatio[s]
)

@constraint(ESM, StorageDischargeFunction[y in year,r in regions,s in storages, h in hour, f in fuels; StorageDischargeEfficiency[s,f]>0], 
    StorageDischarge[y,r,s,h,f] <= AccumulatedStorageEnergyCapacity[y,r,s,f]/E2PRatio[s]
)

@constraint(ESM, StorageLevelFunction[y in year,r in regions,s in storages, h in hour, f in fuels; h>1 && StorageDischargeEfficiency[s,f]>0], 
    StorageLevel[y,r,s,h,f] == StorageLevel[y,r,s,h-1,f]*StorageLosses[s,f] + StorageCharge[y,r,s,h,f]*StorageChargeEfficiency[s,f] - StorageDischarge[y,r,s,h,f]/StorageDischargeEfficiency[s,f]
)

@constraint(ESM, StorageLevelStartFunction[y in year,r in regions,s in storages, h in hour, f in fuels; h==1 && StorageDischargeEfficiency[s,f]>0], 
    StorageLevel[y,r,s,h,f] == 0.5*AccumulatedStorageEnergyCapacity[y,r,s,f]*StorageLosses[s,f] + StorageCharge[y,r,s,h,f]*StorageChargeEfficiency[s,f] - StorageDischarge[y,r,s,h,f]/StorageDischargeEfficiency[s,f]
)

@constraint(ESM, MaxStorageLevelFunction[y in year,r in regions,s in storages, h in hour, f in fuels; StorageDischargeEfficiency[s,f]>0], 
    StorageLevel[y,r,s,h,f] <= AccumulatedStorageEnergyCapacity[y,r,s,f]
)

@constraint(ESM, StorageAnnualBalanceFunction[y in year,r in regions,s in storages, f in fuels; StorageDischargeEfficiency[s,f]>0], 
    StorageLevel[y,r,s,n_hour,f] == 0.5*AccumulatedStorageEnergyCapacity[y,r,s,f]
)

@constraint(ESM, StorageCostFunction[y in year,r in regions,s in storages], 
    TotalStorageCost[y,r,s] == sum(NewStorageEnergyCapacity[y,r,s,f]*InvestmentCostStorage[y,s] for f in fuels if StorageDischargeEfficiency[s,f]>0)
)

@constraint(ESM, StorageMaxCapacityLimit[y in year,r in regions,s in storages],
    sum(AccumulatedStorageEnergyCapacity[y,r,s,f] for f in fuels if StorageDischargeEfficiency[s,f]>0) <= MaxStorageCapacity[y,r,s]
)

@constraint(ESM, ImportExportBalance[y in year,r in regions, rr in regions, h in hour, f in fuels; MaxTradeCapacity[y,r,rr,f]>0],
    Import[y,r,rr,h,f] == Export[y,rr,r,h,f]*(1-TradeLossFactor[f]*TradeDistance[r,rr])
)

@constraint(ESM, MaxImportFunction[y in year,r in regions,rr in regions,h in hour,f in fuels; MaxTradeCapacity[y,r,rr,f]>0],
    Import[y,r,rr,h,f] <= MaxTradeCapacity[y,r,rr,f]
)

# calculate the total installed capacity in each year
@constraint(ESM, CapacityAccountingFunction[y in year, t in technologies, r in regions],
    sum(NewCapacity[yy,r,t] for yy in year if yy<=y && y-yy<= TechnologyLifetime[t])+ResidualCapacity[y,r,t] == AccumulatedCapacity[y,r,t]
)

# account for currently installed storage capacities
@constraint(ESM, StorageCapacityAccountingFunction[y in year, s in storages, r in regions, f in fuels; StorageDischargeEfficiency[s,f]>0],
    sum(NewStorageEnergyCapacity[yy,r,s,f] for yy in year if yy<=y) == AccumulatedStorageEnergyCapacity[y,r,s,f]
)

# account for the total emissions and limit them
@constraint(ESM, TotalEmissionsLimitFunction,
    sum(AnnualTechnologyEmissions[y,r,t] * YearlyDifferenceMultiplier[y] for y in year,t in technologies,r in regions)  
    <= ModelPeriodEmissionLimit
)

#SalvageValue in case it is outside of TechnologyLifetime
@constraint(ESM,SalvageValueOutOfLifetime[y in year,r in regions,t in technologies;TechnologyLifetime[t]<maximum(year)-y],
    SalvageValue[y,r,t] == 0
)

#SalvageValue in case it is within TechnologyLifetime
@constraint(ESM,SalvageValueWithinLifetime[y in year,r in regions,t in technologies;TechnologyLifetime[t]>=maximum(year)-y],
    SalvageValue[y,r,t] == (NewCapacity[y,r,t]*InvestmentCost[y,t])/(1+DiscountRate)^(y - minimum(year)) * (1-((maximum(year)+1-y)/TechnologyLifetime[t]))
)




# the objective function
# total costs should be minimized
@objective(ESM, Min, 
    sum(TotalCost[y,r,t]/ (1+DiscountRate)^(y - minimum(year)) for t in technologies for r in regions, y in year) 
    + sum(TotalStorageCost[y,r,s]/ (1+DiscountRate)^(y - minimum(year)) for s in storages for r in regions, y in year)
    + sum(TradeCostFactor[f]*TradeDistance[r,rr] * Export[y,rr,r,h,f]  * YearlyDifferenceMultiplier[y] / (1+DiscountRate)^(y - minimum(year)) for h in hour, r in regions, rr in regions, f in fuels, y in year if MaxTradeCapacity[y,r,rr,f]>0)
    - sum(SalvageValue[y,r,t] for y in year, r in regions, t in technologies)
    # now, UnmetDemand should also be punished properly so that the model does not try to use it for no reason
    + sum(UnmetDemand[y,r,h,f]*UnmetDemandPenalty[y,r] for y in year, r in regions, h in hour, f in fuels)
    )

# this starts the optimization
# the assigned solver (here Gurobi) will takes care of the solution algorithm
optimize!(ESM)
# reading our objective value

objective_value(ESM)

# we can also analyze specific equations and their marginals / shadow values
println("sum of all technology emissions per year")
println(value.(AnnualEmissionsLimitFunction))
println("marginals for constraint AnnualEmissionsLimitFunction")
println(dual.(AnnualEmissionsLimitFunction))
println("marginals for constraint RegionalAnnualEmissionsLimitFunction")
println(dual.(RegionalAnnualEmissionsLimitFunction))
println("sum of all emissions across the entire modeling horizon")
println(sum(value.(TotalEmissionsLimitFunction)))
println("marginal of constraint TotalEmissionsLimitFunction")
println(dual.(TotalEmissionsLimitFunction))

value.(SalvageValue)

sum(value.(UnmetDemand))
sum(value.(FuelUseByTechnology)*8760/n_hour)

# we will analyze the results in Tableau from now on, so we just need to write our results to csv files
# you can find the code that does this reading, merging, and writing of results in the helper_functions.jl file!
df_energybalance,df_capacity,df_storage_level,df_trade,df_emissions = process_dataframes()
write_result_csvs("",version)

