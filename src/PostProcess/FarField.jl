
"""
在球坐标为r̂θϕ处计算辐射积分，采用RWG基函数时，三角形上没有统一的电流值，每一点上都是三边电流的叠加，
此时:
N(θ, ϕ) =   ∑ₙ(∫ₛ Jˢ exp( jkr̂(θ, ϕ)⋅rₙ ) dS)
        =   ∑ₙ(∫ₛ (∑ₜₙ₌₁³ Iₙfₙ)exp(jkr̂(θ, ϕ)⋅rₙ) dS)
        =   ∑ₙ(Sₜ (∑ₜₙ₌₁³ Iₙlₙρₙ/(2Sₙ))exp(jkr̂(θ, ϕ)⋅rₙ) )
        =   ∑ₙ(∑ᵢWᵢ(∑ₜₙ₌₁³ Iₙlₙρₙ/2)exp(jkr̂(θ, ϕ)⋅rₙ) )
"""
function farField(θs_obs::LinRange{FT}, ϕs_obs::LinRange{FT},
    ICoeff::Vector{CT}, trianglesInfo::Vector{ST}, source, ::Type{BFT} = VSBFTypes.sbfType; str::String = "") where {
        FT<:Real, CT<:Complex, ST<:TriangleInfo, BFT<:RWG}

    # 高斯求积点电流权重乘积
    Jtris       =   electricJCal(ICoeff, trianglesInfo)
    Nθ_obs      =   length(θs_obs)
    Nϕ_obs      =   length(ϕs_obs)

    # 观测角度信息
    nobs        =   Nθ_obs * Nϕ_obs
    θsobsInfo   =   [∠Info{FT}(θ_obs) for θ_obs in θs_obs]
    ϕsobsInfo   =   [∠Info{FT}(ϕ_obs) for ϕ_obs in ϕs_obs]
    r̂θsϕs       =   [r̂θϕInfo{FT}(θobsInfo, ϕobsInfo) for θobsInfo in θsobsInfo, ϕobsInfo in ϕsobsInfo]
    
    # 预分配farE内存
    farEθsϕs    =   zeros(Complex{FT}, (2, length(θsobsInfo), length(ϕsobsInfo)))
    farEθsϕsrsp =   reshape(farEθsϕs, (2, nobs))
    
    # 进度条
    pmeter  =   Progress(nobs, "Calculating farE ($Nθ_obs × $Nϕ_obs)")
    # 计算farE
    @threads for ii in 1:nobs
        # 辐射积分
        Nθϕ     =   raditionalIntegralNθϕCal(r̂θsϕs[ii], trianglesInfo, Jtris)
        # 目标的远场电场
        farEθϕ  =   (-Params.JK_0*η_0*div4π) .* Nθϕ
        # 天线的远场电场
        farEθϕ .+=  sourceFarEfield(source, r̂θsϕs[ii])
        farEθsϕsrsp[:, ii]   .=  farEθϕ
        # 更新进度条
        next!(pmeter)
    end #for ii
    # dB形式 (电场使用 20log10)
    farEθsϕsdB   =   20log10.(farEθsϕs)
    # 总的farE (电场使用 20log10)
    farE         =   farEθsϕs[1, :, :] + farEθsϕs[2, :, :]
    farEdB       =   20log10.(farE)
    # 绘图并保存数据
    farEPlot(θs_obs, ϕs_obs, farE, farEdB; str = str)
    # 返回
    return farEθsϕs, farEθsϕsdB, farE, farEdB

end # end function


"""
在球坐标为r̂θϕ处计算辐射积分，采用SWG基函数时，四面体上没有统一的电流值，每一点上都是四个SWG基函数电流的叠加，
此时:
N(θ, ϕ) =   ∑ₙ(∫ₛ Jˢ exp( jkr̂(θ, ϕ)⋅rₙ ) dS)
        =   ∑ₙ(∫ₛ (∑ₜₙ₌₁³ Iₙfₙ)exp(jkr̂(θ, ϕ)⋅rₙ) dS)
        =   ∑ₙ(Sₜ (∑ₜₙ₌₁³ Iₙsₙρₙ/(3Vₙ))exp(jkr̂(θ, ϕ)⋅rₙ) )
        =   ∑ₙ(∑ᵢWᵢ(∑ₜₙ₌₁³ Iₙsₙρₙ/3)exp(jkr̂(θ, ϕ)⋅rₙ) )
"""
function farField(θs_obs::LinRange{FT}, ϕs_obs::LinRange{FT},
    ICoeff::Vector{CT}, geosInfo::Vector{VT}, source, bfT::Type{BFT}= VSBFTypes.vbfType; str::String = "") where {FT<:Real, VT<:VolumeCellType, CT<:Complex, BFT<:BasisFunctionType}

    # 高斯求积点电流权重乘积
    Jgeos       =   geoElectricJCal(ICoeff, geosInfo, bfT)

    # 观测角度信息
    nobs        =   length(θs_obs) * length(ϕs_obs)
    θsobsInfo   =   [∠Info{FT}(θ_obs) for θ_obs in θs_obs]
    ϕsobsInfo   =   [∠Info{FT}(ϕ_obs) for ϕ_obs in ϕs_obs]
    r̂θsϕs       =   [r̂θϕInfo{FT}(θobsInfo, ϕobsInfo) for θobsInfo in θsobsInfo, ϕobsInfo in ϕsobsInfo]
    
    # 预分配farE内存
    farEθsϕs     =   zeros(Complex{FT}, (2, length(θsobsInfo), length(ϕsobsInfo)))
    farEθsϕsrsp  =   reshape(farEθsϕs, (2, nobs))
    
    # 进度条
    pmeter  =   Progress(nobs, "Calculating farE ($(length(θs_obs)) × $(length(ϕs_obs))))")
    # 计算farE
    @threads for ii in 1:nobs
        # 辐射积分
        Nθϕ     =   raditionalIntegralNθϕCal(r̂θsϕs[ii], geosInfo, Jgeos)
        # farE
        # 目标的远场电场
        farEθϕ  =   (-Params.JK_0*η_0*div4π) .* Nθϕ
        # 天线的远场电场
        farEθϕ .+=  sourceFarEfield(source, r̂θsϕs[ii])
        farEθsϕsrsp[:, ii]   .=  farEθϕ
        # 更新进度条
        next!(pmeter)
    end #for ii
    # dB形式 (电场使用 20log10)
    farEθsϕsdB   =   20log10.(farEθsϕs)
    # 总的farE
    @views farE  =   zeros(FT, (length(θsobsInfo), length(ϕsobsInfo)))
    for iϕ in 1:length(ϕsobsInfo)
        farE[:, iϕ] .=  norm.(eachcol(farEθsϕs[:, :, iϕ]))
    end
    farEdB       =   20log10.(farE)
    # 绘图并保存数据
    farEPlot(θs_obs, ϕs_obs, farE, farEdB; str = str)
    # 返回
    return farEθsϕs, farEθsϕsdB, farE, farEdB

end # end function

"""
在球坐标为r̂θϕ处计算辐射积分，采用SWG基函数时，四面体上没有统一的电流值，每一点上都是四个SWG基函数电流的叠加，
此时:
N(θ, ϕ) =   ∑ₙ(∫ₛ Jˢ exp( jkr̂(θ, ϕ)⋅rₙ ) dS)
        =   ∑ₙ(∫ₛ (∑ₜₙ₌₁³ Iₙfₙ)exp(jkr̂(θ, ϕ)⋅rₙ) dS)
        =   ∑ₙ(Sₜ (∑ₜₙ₌₁³ Iₙsₙρₙ/(3Vₙ))exp(jkr̂(θ, ϕ)⋅rₙ) )
        =   ∑ₙ(∑ᵢWᵢ(∑ₜₙ₌₁³ Iₙsₙρₙ/3)exp(jkr̂(θ, ϕ)⋅rₙ) )
"""
function farField(θs_obs::LinRange{FT}, ϕs_obs::LinRange{FT},
    ICoeff::Vector{CT}, geosInfo::Vector{VT}, source; str::String = "") where {FT<:Real, CT<:Complex, VT<:AbstractVector}
    # 面网格、体网格
    tris    =   geosInfo[1]
    geosV   =   geosInfo[2]
    sbfT    =   getBFTfromCellT(eltype(tris))
    vbfT    =   getBFTfromCellT(eltype(geosV))
    # 高斯求积点电流权重乘积
    Jtris       =   geoElectricJCal(ICoeff, tris,  sbfT)
    JgeoVs      =   geoElectricJCal(ICoeff, geosV, vbfT)

    # 观测角度信息
    nobs        =   length(θs_obs) * length(ϕs_obs)
    θsobsInfo   =   [∠Info{FT}(θ_obs) for θ_obs in θs_obs]
    ϕsobsInfo   =   [∠Info{FT}(ϕ_obs) for ϕ_obs in ϕs_obs]
    r̂θsϕs       =   [r̂θϕInfo{FT}(θobsInfo, ϕobsInfo) for θobsInfo in θsobsInfo, ϕobsInfo in ϕsobsInfo]
    
    # 预分配farE内存
    farEθsϕs     =   zeros(Complex{FT}, (2, length(θsobsInfo), length(ϕsobsInfo)))
    farEθsϕsrsp  =   reshape(farEθsϕs, (2, nobs))
    

    # 进度条
    pmeter  =   Progress(nobs, "Calculating farE ($(length(θs_obs)) × $(length(ϕs_obs))))")
    # 计算farE
    @threads for ii in 1:nobs
        # 辐射积分
        Nθϕ     =   raditionalIntegralNθϕCal(r̂θsϕs[ii], tris,  Jtris)
        Nθϕ   .+=   raditionalIntegralNθϕCal(r̂θsϕs[ii], geosV, JgeoVs)
        # farE
        # 目标的远场电场
        farEθϕ  =   (-Params.JK_0*η_0*div4π) .* Nθϕ
        # 天线的远场电场
        farEθϕ .+=  sourceFarEfield(source, r̂θsϕs[ii])
        farEθsϕsrsp[:, ii]   .=  farEθϕ
        # 更新进度条
        next!(pmeter)
    end #for ii
    # dB形式 (电场使用 20log10)
    farEθsϕsdB   =   20log10.(farEθsϕs)
    # 总的farE
    @views farE  =   zeros(FT, (length(θsobsInfo), length(ϕsobsInfo)))
    for iϕ in 1:length(ϕsobsInfo)
        farE[:, iϕ] .=  norm.(eachcol(farEθsϕs[:, :, iϕ]))
    end
    farEdB       =   20log10.(farE)
    # 绘图并保存数据
    farEPlot(θs_obs, ϕs_obs, farE, farEdB; str = str)
    # 返回
    return farEθsϕs, farEθsϕsdB, farE, farEdB

end # end function



"""
在球坐标为r̂θϕ处计算辐射积分，采用RWG基函数时，三角形上没有统一的电流值，每一点上都是三边电流的叠加，
此时:
N(θ, ϕ) =   ∑ₙ(∫ₛ Jˢ exp( jkr̂(θ, ϕ)⋅rₙ ) dS)
        =   ∑ₙ(∫ₛ (∑ₜₙ₌₁³ Iₙfₙ)exp(jkr̂(θ, ϕ)⋅rₙ) dS)
        =   ∑ₙ(Sₜ (∑ₜₙ₌₁³ Iₙlₙρₙ/(2Sₙ))exp(jkr̂(θ, ϕ)⋅rₙ) )
        =   ∑ₙ(∑ᵢWᵢ(∑ₜₙ₌₁³ Iₙlₙρₙ/2)exp(jkr̂(θ, ϕ)⋅rₙ) )
"""
function farField(θs_obs::LinRange{FT}, ϕs_obs::LinRange{FT}, source; str::String = "") where {FT<:Real}

    Nθ_obs      =   length(θs_obs)
    Nϕ_obs      =   length(ϕs_obs)

    # 观测角度信息
    nobs        =   Nθ_obs * Nϕ_obs
    θsobsInfo   =   [∠Info{FT}(θ_obs) for θ_obs in θs_obs]
    ϕsobsInfo   =   [∠Info{FT}(ϕ_obs) for ϕ_obs in ϕs_obs]
    r̂θsϕs       =   [r̂θϕInfo{FT}(θobsInfo, ϕobsInfo) for θobsInfo in θsobsInfo, ϕobsInfo in ϕsobsInfo]
    
    # 预分配farE内存
    farEθsϕs    =   zeros(Complex{FT}, (2, length(θsobsInfo), length(ϕsobsInfo)))
    farEθsϕsrsp =   reshape(farEθsϕs, (2, nobs))
    
    # 进度条
    pmeter  =   Progress(nobs, "Calculating source farE ($Nθ_obs × $Nϕ_obs)")
    # 计算farE
    @threads for ii in 1:nobs
        # 天线的远场电场
        farEθϕ  =  sourceFarEfield(source, r̂θsϕs[ii])
        farEθsϕsrsp[:, ii]   .=  farEθϕ
        # 更新进度条
        next!(pmeter)
    end #for ii
    # dB形式 (电场使用 20log10)
    farEθsϕsdB   =   20log10.(farEθsϕs)
    # 总的farE
    @views farE  =   zeros(FT, (length(θsobsInfo), length(ϕsobsInfo)))
    for iϕ in 1:length(ϕsobsInfo)
        farE[:, iϕ] .=  norm.(eachcol(farEθsϕs[:, :, iϕ]))
    end
    farEdB       =   20log10.(farE)

    # 保存数据
    open(SimulationParams.resultDir*"farEm2$str.txt", "w") do io
        θs_obs_deg  =   θs_obs/pi*180
        ϕs_obs_deg  =   ϕs_obs/pi*180
        for θii in 1:length(θs_obs_deg)
            write(io, "$(θs_obs_deg[θii])\t")
            for ϕjj in 1:length(ϕs_obs_deg)
                write(io, "$(farE[θii, ϕjj])\t")
            end
            write(io, "\n")
        end
    end
    # 绘图
    SimulationParams.SHOWIMAGE && farEPlot(θs_obs, ϕs_obs, farE, farEdB; str = str)
    # 返回
    return farEθsϕs, farEθsϕsdB, farE, farEdB

end # end function


"""
farE 绘图
"""
function farEPlot(θs_obs::LinRange{FT}, ϕs_obs::LinRange{FT}, farE::Matrix{FT}, farEdB::Matrix{FT}; str::String = "") where{FT<:Real}
    
    θs_obs_deg  =   θs_obs/pi*180
    ϕs_obs_deg  =   ϕs_obs/pi*180
    # 标签
    labels  =   reshape(["ϕ = $(ϕ_obs_deg)°" for ϕ_obs_deg in ϕs_obs_deg], (1, length(ϕs_obs_deg)))
    # 绘图
    figfarEm²  = lineplot(θs_obs_deg, farE; name = labels, xlim = extrema(θs_obs_deg), ylim = extrema(farE), xlabel="θ", ylabel="m²", title = "farE(m²)(θϕ)$str")
    figfarEdB  = lineplot(θs_obs_deg, farEdB; name = labels, xlim = extrema(θs_obs_deg), ylim = extrema(farEdB), xlabel="θ", ylabel="dB", title = "farE(dB)(θϕ)$str")

    SimulationParams.SHOWIMAGE && display(figfarEm²)
    SimulationParams.SHOWIMAGE && display(figfarEdB)

    return figfarEdB

end