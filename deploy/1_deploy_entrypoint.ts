import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { Create2Factory } from '../src/Create2Factory'
import { ethers } from 'hardhat'

const privateKey = '2ceb69af7ead01cb21bf06b009870d99fb890059a6c10915900d979819d67fce'

const deployEntryPoint: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const provider = ethers.provider
  const from = await provider.getSigner().getAddress()
  const newWallet = new ethers.Wallet(privateKey)
  const signerProvider = newWallet.connect(provider)
  const from2 = signerProvider.address
  console.log('from 213124', from)
  console.log('from 2', from2)
  await new Create2Factory(ethers.provider).deployFactory()

  const ret = await hre.deployments.deploy(
    'EntryPoint', {
      from,
      args: [],
      gasLimit: 6e6,
      deterministicDeployment: true
    })
  console.log('==entrypoint addr=', ret.address)
}

export default deployEntryPoint
